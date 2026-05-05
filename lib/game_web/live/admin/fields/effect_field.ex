defmodule GameWeb.Admin.Fields.EffectField do
  @moduledoc """
  A Backpex field for the effect `value` column that renders one FormulaEditorComponent
  per parameter key declared by the effect type's CardEffect.params/0 implementation.

  The stored value is a map keyed by param name, e.g.:
    %{"value" => 3, "damage" => 5}   for dot
    %{"q" => 1, "r" => 0, "s" => -1} for move
    %{"value" => 2}                   for damage/heal/shield/etc.
  """
  use Backpex.Field

  @impl Backpex.Field
  def render_value(assigns) do
    label =
      case assigns.value do
        v when is_map(v) and map_size(v) > 0 -> Jason.encode!(v)
        v when is_binary(v) -> v
        v when is_number(v) -> to_string(v)
        _ -> ""
      end

    assigns = assign(assigns, :label, label)

    ~H"""
    <span class="font-mono text-xs">{@label}</span>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    # Read the effect type from the embedded item form (sibling :type field)
    effect_type = Phoenix.HTML.Form.input_value(assigns.form, :type) || ""
    params = Game.Card.effect_params(effect_type)

    raw_value = Phoenix.HTML.Form.input_value(assigns.form, assigns.name)

    value_map =
      case raw_value do
        # Already a params map (has non-operator keys or multiple keys)
        v when is_map(v) and map_size(v) > 0 ->
          if params_map?(v), do: v, else: %{"value" => v}

        v when is_integer(v) ->
          %{"value" => v}

        v when is_binary(v) and v != "" ->
          %{"value" => v}

        _ ->
          %{}
      end

    assigns =
      assigns
      |> assign(:params, params)
      |> assign(:value_map, value_map)
      |> assign(:field_base, "#{assigns.form[assigns.name].name}")

    ~H"""
    <div class="flex flex-col gap-2">
      <%= for param <- @params do %>
        <div class="flex flex-col gap-1">
          <label class="label-text text-xs opacity-70">{param}</label>
          <.live_component
            module={GameWeb.FormulaEditorComponent}
            id={"effect-#{@form[@name].id}-#{@name}-#{param}"}
            value={Map.get(@value_map, param, %{})}
            field={"#{@field_base}[#{param}]"}
            path={[]}
            context={:effect}
          />
        </div>
      <% end %>
    </div>
    """
  end

  # A params map has multiple keys OR its single key is not a JsonLogic operator.
  # A formula map has exactly one key which is a known operator (e.g. %{"+" => [...]}).
  @formula_operators MapSet.new(~w(var == === != !== ! !! if or and > >= < <= max min + - * / % map filter reduce all none some in cat log alias))

  defp params_map?(map) do
    keys = Map.keys(map)
    length(keys) != 1 or hd(keys) not in @formula_operators
  end
end
