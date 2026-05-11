defmodule Mix.Tasks.Game.PullContentSync do
  use Mix.Task
  alias Ecto.Migrator
  alias Game.BaseCards.BaseCard
  alias Game.BaseDecks.BaseDeck
  alias Game.Content.{BaseDeckCard, BaseClass, Strategy}
  alias Game.FormulaAliases.FormulaAlias
  alias Game.Maps.Map

  @shortdoc "Pulls production content (cards/decks/classes) into local database"

  @impl Mix.Task
  def run(_args) do
    unless System.get_env("PROD_DATABASE_URL") do
      Mix.shell().error("PROD_DATABASE_URL environment variable is not set")
      exit({:shutdown, 1})
    end

    {:ok, _} = Application.ensure_all_started(:game)

    Migrator.with_repo(
      Game.ProdRepo,
      [queue_target: 10_000, queue_interval: 10_000],
      fn _prod_repo ->
        Mix.shell().info("Reading production data...")

        prod_cards = Game.ProdRepo.all(BaseCard)
        prod_decks = Game.ProdRepo.all(BaseDeck)
        prod_deck_cards = Game.ProdRepo.all(BaseDeckCard)
        prod_classes = Game.ProdRepo.all(BaseClass)
        prod_strategies = Game.ProdRepo.all(Strategy)
        prod_formula_aliases = Game.ProdRepo.all(FormulaAlias)
        prod_maps = Game.ProdRepo.all(Map)

        Mix.shell().info(
          "Found: #{length(prod_cards)} cards, #{length(prod_decks)} decks, " <>
            "#{length(prod_deck_cards)} deck_cards, #{length(prod_classes)} classes, " <>
            "#{length(prod_strategies)} strategies, #{length(prod_formula_aliases)} formula_aliases, " <>
            "#{length(prod_maps)} maps"
        )

        Mix.shell().info("Syncing to local database...")

        Game.Repo.transaction(fn ->
          Game.Repo.delete_all(BaseClass)
          Game.Repo.delete_all(BaseDeckCard)
          Game.Repo.delete_all(BaseDeck)
          Game.Repo.delete_all(BaseCard)
          Game.Repo.delete_all(Strategy)
          Game.Repo.delete_all(FormulaAlias)
          Game.Repo.delete_all(Map)

          formula_alias_id_map =
            Enum.reduce(prod_formula_aliases, %{}, fn prod_formula_alias, acc ->
              local_formula_alias =
                %FormulaAlias{}
                |> FormulaAlias.changeset(%{
                  name: prod_formula_alias.name,
                  expression: prod_formula_alias.expression,
                  description: prod_formula_alias.description
                })
                |> Game.Repo.insert!()

              Map.put(acc, prod_formula_alias.id, local_formula_alias.id)
            end)

          strategy_id_map =
            Enum.reduce(prod_strategies, %{}, fn prod_strategy, acc ->
              tactics_attrs =
                Enum.map(prod_strategy.tactics, fn e ->
                  Map.take(e, [:trigger, :action, :card_filter])
                end)

              local_strategy =
                %Strategy{}
                |> Strategy.changeset(%{
                  name: prod_strategy.name,
                  tactics: tactics_attrs
                })
                |> Game.Repo.insert!()

              Map.put(acc, prod_strategy.id, local_strategy.id)
            end)

          card_id_map =
            Enum.reduce(prod_cards, %{}, fn prod_card, acc ->
              effects_attrs =
                Enum.map(prod_card.effects, fn e ->
                  Map.take(e, [
                    :type,
                    :value,
                    :value_label,
                    :range,
                    :multi,
                    :scaling,
                    :conditional
                  ])
                end)

              local_card =
                %BaseCard{}
                |> BaseCard.changeset(%{
                  name: prod_card.name,
                  ap: prod_card.ap,
                  range: prod_card.range,
                  headline: prod_card.headline,
                  rarity: prod_card.rarity,
                  targeting: prod_card.targeting,
                  effects: effects_attrs
                })
                |> Game.Repo.insert!()

              Map.put(acc, prod_card.id, local_card.id)
            end)

          deck_id_map =
            Enum.reduce(prod_decks, %{}, fn prod_deck, acc ->
              local_deck =
                %BaseDeck{}
                |> BaseDeck.changeset(%{name: prod_deck.name})
                |> Game.Repo.insert!()

              Map.put(acc, prod_deck.id, local_deck.id)
            end)

          Enum.each(prod_deck_cards, fn bdc ->
            Game.Repo.insert!(%BaseDeckCard{
              count: bdc.count,
              card_id: Map.fetch!(card_id_map, bdc.card_id),
              deck_id: Map.fetch!(deck_id_map, bdc.deck_id)
            })
          end)

          Enum.each(prod_maps, fn prod_map ->
            %Map{}
            |> Map.changeset(%{
              slug: prod_map.slug,
              display_name: prod_map.display_name,
              tiles: prod_map.tiles,
              spawn_points: prod_map.spawn_points
            })
            |> Game.Repo.insert!()
          end)

          Enum.each(prod_classes, fn cls ->
            local_deck_id = cls.deck_id && Map.fetch!(deck_id_map, cls.deck_id)
            local_strategy_id = cls.strategy_id && Map.fetch!(strategy_id_map, cls.strategy_id)

            %BaseClass{}
            |> BaseClass.changeset(%{
              class: cls.class,
              avatar_url: cls.avatar_url,
              base_hp: cls.base_hp,
              base_ap: cls.base_ap,
              base_movement: cls.base_movement,
              deck_id: local_deck_id,
              strategy_id: local_strategy_id
            })
            |> Game.Repo.insert!()
          end)
        end)

        Mix.shell().info("Sync complete.")
      end
    )
  end
end
