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
        searchable: true,
        default: fn assigns -> Map.get(assigns.params, "name") end
      },
      headline: %{
        module: Backpex.Fields.Text,
        label: "Headline",
        default: fn assigns -> Map.get(assigns.params, "headline") end
      },
      ap: %{
        module: Backpex.Fields.Number,
        label: "AP",
        default: fn assigns ->
          case Integer.parse(Map.get(assigns.params, "ap", "")) do
            {v, ""} -> v
            _ -> nil
          end
        end
      },
      range: %{
        module: Backpex.Fields.Number,
        label: "Range",
        default: fn assigns ->
          case Integer.parse(Map.get(assigns.params, "range", "")) do
            {v, ""} -> v
            _ -> nil
          end
        end
      },
      rarity: %{
        module: Backpex.Fields.Select,
        label: "Rarity",
        options: [
          {"Common", :common},
          {"Uncommon", :uncommon},
          {"Rare", :rare},
          {"Legendary", :legendary}
        ],
        default: fn assigns ->
          case Map.get(assigns.params, "rarity") do
            s when s in [nil, ""] -> nil
            s -> String.to_existing_atom(s)
          end
        end
      },
      targeting: %{
        module: GameWeb.Admin.Fields.TargetingField,
        label: "Targeting",
        default: fn assigns ->
          case Map.get(assigns.params, "clone_targeting") do
            s when s in [nil, ""] -> nil
            json -> with {:ok, v} <- Jason.decode(json), do: v
          end
        end
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
          range: %{
            module: Backpex.Fields.Number,
            label: "Blast Radius"
          },
          target_formula: %{
            module: GameWeb.Admin.Fields.FormulaField,
            label: "Target Formula"
          },
          value: %{
            module: GameWeb.Admin.Fields.EffectField,
            label: "Parameters"
          }
        ],
        default: fn assigns ->
          case Map.get(assigns.params, "clone_effects") do
            s when s in [nil, ""] -> []
            json ->
              case Jason.decode(json) do
                {:ok, list} when is_list(list) -> list
                _ -> []
              end
          end
        end
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

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    Enum.concat(default_actions, clone: %{module: __MODULE__.Clone, only: [:row]})
  end

  defmodule Clone do
    use BackpexWeb, :item_action

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H"""
      <Backpex.HTML.CoreComponents.icon
        name="hero-document-duplicate"
        class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110"
      />
      """
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Clone"

    @impl Backpex.ItemAction
    def link(assigns, item) do
      Backpex.Router.get_path(assigns.socket, assigns.live_resource, assigns.params, :new, %{
        "name" => "Copy of #{item.name}",
        "headline" => item.headline || "",
        "ap" => to_string(item.ap || ""),
        "range" => to_string(item.range || ""),
        "rarity" => to_string(item.rarity || ""),
        "clone_targeting" => Jason.encode!(item.targeting || %{}),
        "clone_effects" => Jason.encode!(item.effects || [])
      })
    end
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

    effect
    |> Map.put("value", flattened)
    |> parse_target_formula()
  end

  defp parse_effect_value(effect), do: parse_target_formula(effect)

  defp parse_target_formula(%{"target_formula" => params} = effect) when is_map(params) do
    %{effect | "target_formula" => Game.Formula.parse_params(params)}
  end

  defp parse_target_formula(effect), do: effect
end
