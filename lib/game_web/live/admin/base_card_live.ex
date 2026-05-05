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
      range: %{
        module: Backpex.Fields.Number,
        label: "Range"
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
            module: GameWeb.Admin.Fields.EffectField,
            label: "Parameters"
          }
        ]
      }
    ]
  end

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
    |> parse_effect_values()
    |> then(&Game.BaseCards.BaseCard.changeset(item, &1))
  end

  defp parse_targeting(%{"targeting" => %{"rule" => rule_params} = targeting} = attrs) do
    %{attrs | "targeting" => %{targeting | "rule" => Game.Formula.parse_params(rule_params)}}
  end

  defp parse_targeting(attrs), do: attrs

  defp parse_effect_values(%{"effects" => effects} = attrs) when is_map(effects) do
    parsed = Map.new(effects, fn {k, effect} -> {k, parse_effect_value(effect)} end)
    %{attrs | "effects" => parsed}
  end

  defp parse_effect_values(attrs), do: attrs

  # The value submitted for an effect is a map keyed by param name (e.g. %{"value" => ..., "damage" => ...}).
  # Each param value is a formula params map (from FormulaEditorComponent) and must be parsed.
  defp parse_effect_value(%{"value" => value} = effect) when is_map(value) do
    parsed_params =
      Map.new(value, fn {param_key, param_value} ->
        {param_key, Game.Formula.parse_params(param_value)}
      end)

    # Flatten: if the only param is "value", store scalar directly for backwards compat
    flattened =
      case parsed_params do
        %{"value" => scalar} when map_size(parsed_params) == 1 -> scalar
        _ -> parsed_params
      end

    %{effect | "value" => flattened}
  end

  defp parse_effect_value(effect), do: effect
end
