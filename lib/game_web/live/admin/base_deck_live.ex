defmodule GameWeb.Admin.BaseDeckLive do
  use Backpex.LiveResource,
    init_order: %{by: :name, direction: :asc},
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
      },
      base_deck_cards: %{
        module: Backpex.Fields.InlineCRUD,
        label: "Cards",
        orderable: false,
        type: :assoc,
        render: fn assigns ->
          cards = Game.Content.get_base_deck_cards(assigns.item)
          |> Enum.map(&Map.take(&1, [:id, :name, :rarity]))
          |> Enum.map(fn %{name: name} = card ->
              acronym = name
              |> String.split(" ")
              |> Enum.map(fn word -> String.slice(word, 0..0) end)
              |> Enum.join("")

              Map.put(card, :acronym, acronym)
            end
              )
            |> Enum.sort_by(& &1.rarity)
          ~H"""
        <div class="flex flex-wrap gap-1">
          <div :for={card <- cards} class="tooltip" data-tip={card.name}>
            <a class={["badge px-1 w-8", rarity_bg_class(card.rarity)]} href={"/admin/base_cards/#{card.id}/show"}>
            {card.acronym}
            </a>
          </div>
        </div>
        """
      end,
        child_fields: [
          card_id: %{
            module: Backpex.Fields.Select,
            label: "Card",
            options:
              Game.Repo.all(Game.BaseCards.BaseCard)
              |> Enum.map(&{&1.name, &1.id})
              |> Enum.sort_by(&elem(&1, 0))
          },
          count: %{
            module: Backpex.Fields.Number,
            label: "Count"
          }
        ]
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
        to:
          "/admin/base_cards?filters[deck]=#{item.id}&page=1&order_by=name&order_direction=asc&per_page=100"
      )
      |> ok()
    end
  end

  defp rarity_bg_class(:common), do: "bg-common"
  defp rarity_bg_class(:uncommon), do: "bg-uncommon"
  defp rarity_bg_class(:rare), do: "bg-rare"
  defp rarity_bg_class(:legendary), do: "bg-legendary"
  defp rarity_bg_class(_), do: "bg-base-300"
end
