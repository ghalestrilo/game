defmodule Mix.Tasks.Game.PullContentSync do
  use Mix.Task
  alias Ecto.Migrator
  alias Game.BaseCards.BaseCard
  alias Game.BaseDecks.BaseDeck
  alias Game.Content.{BaseDeckCard, BaseClass}

  @shortdoc "Pulls production content (cards/decks/classes) into local database"

  @impl Mix.Task
  def run(_args) do
    # TODO: UPDATE PULL TO REFLECT CHANGES ON PUSH
    Mix.shell().error("PULL SCRIPT IS OUTDATED WITH PUSH, PLEASE FIX BEFORE RUNNING")
    exit({:shutdown, 1})

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

        Mix.shell().info(
          "Found: #{length(prod_cards)} cards, #{length(prod_decks)} decks, " <>
            "#{length(prod_deck_cards)} deck_cards, #{length(prod_classes)} classes"
        )

        Mix.shell().info("Syncing to local database...")

        Game.Repo.transaction(fn ->
          Game.Repo.delete_all(BaseClass)
          Game.Repo.delete_all(BaseDeckCard)
          Game.Repo.delete_all(BaseDeck)
          Game.Repo.delete_all(BaseCard)

          card_id_map =
            Enum.reduce(prod_cards, %{}, fn prod_card, acc ->
              effects_attrs =
                Enum.map(prod_card.effects, fn e ->
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

          Enum.each(prod_classes, fn cls ->
            local_deck_id = cls.deck_id && Map.fetch!(deck_id_map, cls.deck_id)

            %BaseClass{}
            |> BaseClass.changeset(%{
              class: cls.class,
              avatar_url: cls.avatar_url,
              base_hp: cls.base_hp,
              base_ap: cls.base_ap,
              base_movement: cls.base_movement,
              deck_id: local_deck_id
            })
            |> Game.Repo.insert!()
          end)
        end)

        Mix.shell().info("Sync complete.")
      end
    )
  end
end
