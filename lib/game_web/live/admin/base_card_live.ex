defmodule GameWeb.Admin.BaseCardLive do
  use Backpex.LiveResource,
    per_page_default: 100,
    init_order: %{by: :name, direction: :asc},
    adapter_config: [
      schema: Game.BaseCards.BaseCard,
      repo: Game.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ]

  @impl Backpex.LiveResource
  def layout(_assigns), do: {GameWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Base Card"

  @impl Backpex.LiveResource
  def plural_name, do: "Base Cards"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true
      },
      headline: %{
        module: Backpex.Fields.Text,
        label: "Headline"
      },
      ap: %{
        module: Backpex.Fields.Number,
        label: "AP"
      },
      rarity: %{
        module: Backpex.Fields.Select,
        label: "Rarity",
        options: [
          {"Common", :common},
          {"Uncommon", :uncommon},
          {"Rare", :rare},
          {"Legendary", :legendary}
        ]
      },
      targeting: %{
        module: GameWeb.Admin.Fields.TargetingField,
        label: "Targeting"
      },
      effects: %{
        module: Backpex.Fields.InlineCRUD,
        label: "Effects",
        orderable: false,
        type: :embed,
        child_fields: [
          type: %{
            module: Backpex.Fields.Select,
            label: "Type",
            options:
              Game.Card.effect_types() |> Map.keys() |> Enum.map(&{String.capitalize(&1), &1})
          },
          value: %{
            module: Backpex.Fields.Text,
            label: "Value"
          }
        ]
      }
    ]
  end

  def handle_info({:formula_updated, _path, _value}, socket), do: {:noreply, socket}
  def handle_info({:formula_remove_node, _path}, socket), do: {:noreply, socket}

  @impl Backpex.LiveResource
  def filters do
    [
      deck: %{
        module: GameWeb.Admin.Filters.DeckFilter
      }
    ]
  end

  def changeset(item, attrs, _metadata) do
    attrs
    |> parse_targeting()
    |> then(&Game.BaseCards.BaseCard.changeset(item, &1))
  end

  defp parse_targeting(%{"targeting" => %{"rule" => rule_params} = targeting} = attrs) do
    %{attrs | "targeting" => %{targeting | "rule" => Game.Formula.parse_params(rule_params)}}
  end

  defp parse_targeting(attrs), do: attrs
end
