defmodule Mix.Tasks.Game.PushContentSync do
  use Mix.Task
  alias Ecto.Migrator
  alias Game.BaseCards.BaseCard
  alias Game.BaseDecks.BaseDeck
  alias Game.Content.{BaseDeckCard, BaseClass, Strategy}
  alias Game.FormulaAliases.FormulaAlias

  @shortdoc "Pushes local content (cards/decks/classes) into production database"

  @impl Mix.Task
  def run(_args) do
    unless System.get_env("PROD_DATABASE_URL") do
      Mix.shell().error("PROD_DATABASE_URL environment variable is not set")
      exit({:shutdown, 1})
    end

    {:ok, _} = Application.ensure_all_started(:game)

    Migrator.with_repo(Game.ProdRepo, fn _prod_repo ->
      Mix.shell().info("Reading local data...")

      local_cards = Game.Repo.all(BaseCard)
      local_decks = Game.Repo.all(BaseDeck)
      local_deck_cards = Game.Repo.all(BaseDeckCard)
      local_classes = Game.Repo.all(BaseClass)
      local_strategies = Game.Repo.all(Strategy)
      local_formula_aliases = Game.Repo.all(FormulaAlias)

      Mix.shell().info(
        "Found: #{length(local_cards)} cards, #{length(local_decks)} decks, " <>
          "#{length(local_deck_cards)} deck_cards, #{length(local_classes)} classes, " <>
          "#{length(local_strategies)} strategies, #{length(local_formula_aliases)} formula_aliases"
      )

      Mix.shell().info("Syncing to production database...")

      Game.ProdRepo.transaction(fn ->
        Game.ProdRepo.delete_all(BaseClass)
        Game.ProdRepo.delete_all(BaseDeckCard)
        Game.ProdRepo.delete_all(BaseDeck)
        Game.ProdRepo.delete_all(BaseCard)
        Game.ProdRepo.delete_all(Strategy)
        Game.ProdRepo.delete_all(FormulaAlias)

        formula_alias_id_map =
          Enum.reduce(local_formula_aliases, %{}, fn local_formula_alias, acc ->
            prod_formula_alias =
              %FormulaAlias{}
              |> FormulaAlias.changeset(%{
                name: local_formula_alias.name,
                expression: local_formula_alias.expression,
                description: local_formula_alias.description
              })
              |> Game.ProdRepo.insert!()

            Map.put(acc, local_formula_alias.id, prod_formula_alias.id)
          end)

        strategy_id_map =
          Enum.reduce(local_strategies, %{}, fn local_strategy, acc ->
            tactics_attrs =
              Enum.map(local_strategy.tactics, fn e ->
                Map.take(e, [:trigger, :action, :card_filter])
              end)

            prod_strategy =
              %Strategy{}
              |> Strategy.changeset(%{
                name: local_strategy.name,
                tactics: tactics_attrs
              })
              |> Game.ProdRepo.insert!()

            Map.put(acc, local_strategy.id, prod_strategy.id)
          end)

        card_id_map =
          Enum.reduce(local_cards, %{}, fn local_card, acc ->
            effects_attrs =
              Enum.map(local_card.effects, fn e ->
                Map.take(e, [
                  :type,
                  :value,
                  :value_label,
                  :aoe,
                  :range,
                  :multi,
                  :scaling,
                  :conditional
                ])
              end)

            prod_card =
              %BaseCard{}
              |> BaseCard.changeset(%{
                name: local_card.name,
                ap: local_card.ap,
                range: local_card.range,
                headline: local_card.headline,
                rarity: local_card.rarity,
                targeting: local_card.targeting,
                effects: effects_attrs
              })
              |> Game.ProdRepo.insert!()

            Map.put(acc, local_card.id, prod_card.id)
          end)

        deck_id_map =
          Enum.reduce(local_decks, %{}, fn local_deck, acc ->
            prod_deck =
              %BaseDeck{}
              |> BaseDeck.changeset(%{name: local_deck.name})
              |> Game.ProdRepo.insert!()

            Map.put(acc, local_deck.id, prod_deck.id)
          end)

        Enum.each(local_deck_cards, fn bdc ->
          Game.ProdRepo.insert!(%BaseDeckCard{
            count: bdc.count,
            card_id: Map.fetch!(card_id_map, bdc.card_id),
            deck_id: Map.fetch!(deck_id_map, bdc.deck_id)
          })
        end)

        Enum.each(local_classes, fn cls ->
          prod_deck_id = cls.deck_id && Map.fetch!(deck_id_map, cls.deck_id)
          prod_strategy_id = cls.strategy_id && Map.fetch!(strategy_id_map, cls.strategy_id)

          %BaseClass{}
          |> BaseClass.changeset(%{
            class: cls.class,
            avatar_url: cls.avatar_url,
            base_hp: cls.base_hp,
            base_ap: cls.base_ap,
            base_movement: cls.base_movement,
            deck_id: prod_deck_id,
            strategy_id: prod_strategy_id
          })
          |> Game.ProdRepo.insert!()
        end)
      end)

      Mix.shell().info("Sync complete.")
    end)
  end
end
