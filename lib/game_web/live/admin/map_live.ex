defmodule GameWeb.Admin.MapLive do
  use Backpex.LiveResource,
    init_order: %{by: :display_name, direction: :asc},
    adapter_config: [
      schema: Game.Maps.Map,
      repo: Game.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ]

  @impl Backpex.LiveResource
  def layout(_assigns), do: {GameWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Map"

  @impl Backpex.LiveResource
  def plural_name, do: "Maps"

  @impl Backpex.LiveResource
  def fields do
    [
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        searchable: true
      },
      display_name: %{
        module: Backpex.Fields.Text,
        label: "Display Name",
        searchable: true
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    Enum.concat(default_actions, edit_tiles: %{module: __MODULE__.EditTiles, only: [:row]})
  end

  def changeset(item, attrs, _metadata) do
    Game.Maps.Map.changeset(item, attrs)
  end

  defmodule EditTiles do
    use BackpexWeb, :item_action

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H"""
      <Backpex.HTML.CoreComponents.icon
        name="hero-map"
        class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110"
      />
      """
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Edit Tiles"

    @impl Backpex.ItemAction
    def handle(socket, [item | _], _params) do
      socket
      |> Phoenix.LiveView.push_navigate(to: "/admin/maps/#{item.id}/edit-tiles")
      |> ok()
    end
  end
end
