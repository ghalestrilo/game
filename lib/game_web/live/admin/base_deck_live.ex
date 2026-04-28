defmodule GameWeb.Admin.BaseDeckLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Game.BaseDecks.BaseDeck,
      repo: Game.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ]

  @impl Backpex.LiveResource
  def layout(_assigns), do: {GameWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Base Deck"

  @impl Backpex.LiveResource
  def plural_name, do: "Base Decks"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true
      }
    ]
  end

  def changeset(item, attrs, _metadata) do
    Game.BaseDecks.BaseDeck.changeset(item, attrs)
  end
end
