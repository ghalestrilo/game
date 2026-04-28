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

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    Enum.concat(default_actions, edit_cards: %{module: __MODULE__.EditCards, only: [:row]})
  end

  def changeset(item, attrs, _metadata) do
    Game.BaseDecks.BaseDeck.changeset(item, attrs)
  end

  defmodule EditCards do
    use BackpexWeb, :item_action

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H"""
      <Backpex.HTML.CoreComponents.icon
        name="hero-rectangle-stack"
        class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110"
      />
      """
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Edit cards"

    @impl Backpex.ItemAction
    def handle(socket, [item | _], _params) do
      socket
      |> Phoenix.LiveView.push_navigate(
        to: "/admin/base_cards?filters[deck]=#{item.id}&page=1&order_by=name&order_direction=asc&per_page=100"
      )
      |> ok()
    end
  end
end
