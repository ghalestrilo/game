defmodule GameWeb.Admin.Fields.EffectField do
  @moduledoc """
  A Backpex field for the `:effects` embed on BaseCard.

  Owns the full InlineCRUD-style list rendering: inputs_for loop, sibling fields
  (type, range, target_formula), delete/add buttons, and the per-param fieldset.
  """
  use Backpex.Field

  @modifiable_attributes ~w(max_hp max_ap movement_range hand_size damage_multiplier outgoing_damage_multiplier)

  @child_fields [
    type: %{
      module: Backpex.Fields.Select,
      label: "Type",
      options: Game.Card.effect_types() |> Map.keys() |> Enum.map(&{String.capitalize(&1), &1})
    },
    range: %{module: Backpex.Fields.Number, label: "Blast Radius"},
    target_formula: %{module: GameWeb.Admin.Fields.FormulaField, label: "Target Formula"}
  ]

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
    assigns = assign(assigns, :child_fields, @child_fields)

    ~H"""
    <div>
    <Backpex.HTML.Layout.field_container>
      <:label align="top">
        <Backpex.HTML.Layout.input_label
          id={"inline-crud-label-#{@name}"}
          as="span"
          text={@field_options[:label]}
        />
      </:label>

      <div class="flex flex-col gap-3">
        <.inputs_for :let={f_nested} field={@form[@name]}>
          <input
            type="hidden"
            name={"change[#{@name}_order][]"}
            value={f_nested.index}
            tabindex="-1"
            aria-hidden="true"
          />

          <div class="card bg-base-200">
            <div class="card-body p-4 gap-3">
              <div class="flex gap-4 items-end">
                {Backpex.HTML.Resource.resource_form_field(
                  assign(assigns, fields: @child_fields, name: :type, form: f_nested, hide_label: false)
                )}
                {Backpex.HTML.Resource.resource_form_field(
                  assign(assigns, fields: @child_fields, name: :range, form: f_nested, hide_label: false)
                )}
                <label for={"#{@name}-checkbox-delete-#{f_nested.index}"} class="ml-auto pb-1">
                  <input
                    id={"#{@name}-checkbox-delete-#{f_nested.index}"}
                    type="checkbox"
                    name={"change[#{@name}_delete][]"}
                    value={f_nested.index}
                    class="hidden"
                  />
                  <div class="btn btn-outline btn-error btn-sm">
                    <Backpex.HTML.CoreComponents.icon name="hero-trash" class="size-5" />
                  </div>
                </label>
              </div>

              {Backpex.HTML.Resource.resource_form_field(
                assign(assigns, fields: @child_fields, name: :target_formula, form: f_nested, hide_label: false)
              )}

              {render_param_fieldset(assign(assigns, :f_nested, f_nested))}
            </div>
          </div>
        </.inputs_for>

        <input
          type="hidden"
          name={"change[#{@name}_delete][]"}
          tabindex="-1"
          aria-hidden="true"
        />
      </div>

      <input
        name={"change[#{@name}_order][]"}
        type="checkbox"
        aria-label="Add entry"
        class="btn btn-outline btn-sm btn-primary mt-2"
      />
    </Backpex.HTML.Layout.field_container>
    </div>
    """
  end

  defp render_param_fieldset(assigns) do
    f = assigns.f_nested
    effect_type = Phoenix.HTML.Form.input_value(f, :type) || ""
    params = Game.Card.effect_params(effect_type)
    raw_value = Phoenix.HTML.Form.input_value(f, :value)
    field_base = "#{f[:value].name}"

    value_map =
      case raw_value do
        v when is_map(v) and map_size(v) > 0 ->
          if params_map?(v), do: v, else: %{"value" => v}
        v when is_integer(v) -> %{"value" => v}
        v when is_binary(v) and v != "" -> %{"value" => v}
        _ -> %{}
      end

    assigns =
      assigns
      |> assign(:params, params)
      |> assign(:value_map, value_map)
      |> assign(:effect_type, effect_type)
      |> assign(:field_base, field_base)
      |> assign(:modifiable_attributes, @modifiable_attributes)

    ~H"""
    <fieldset class="fieldset">
      <legend class="fieldset-legend">{@effect_type}</legend>
      <%= for param <- @params do %>
        <label class="fieldset-label">{param}</label>
        <%= cond do %>
          <% param == "card" -> %>
            <select name={"#{@field_base}[card][value]"} class="select select-sm w-full">
              <option value="">-- Select card --</option>
              <%= for base_card <- list_base_cards() do %>
                <option
                  value={base_card.id}
                  selected={to_string(base_card.id) == to_string(Map.get(@value_map, "card", ""))}
                >
                  {base_card.name}
                </option>
              <% end %>
            </select>
          <% param == "pile" -> %>
            <select name={"#{@field_base}[pile][value]"} class="select select-sm w-full">
              <%= for pile <- ["hand", "draw", "discard"] do %>
                <option
                  value={pile}
                  selected={pile == to_string(Map.get(@value_map, "pile", "hand"))}
                >
                  {pile}
                </option>
              <% end %>
            </select>
          <% param == "trajectory" -> %>
            <select name={"#{@field_base}[trajectory][value]"} class="select select-sm w-full">
              <%= for trajectory <- ["slide", "linear", "null"] do %>
                <option
                  value={trajectory}
                  selected={trajectory == to_string(Map.get(@value_map, "trajectory", "slide"))}
                >
                  {trajectory}
                </option>
              <% end %>
            </select>
          <% param == "attribute" -> %>
            <select name={"#{@field_base}[attribute][value]"} class="select select-sm w-full">
              <%= for attr <- @modifiable_attributes do %>
                <option
                  value={attr}
                  selected={attr == to_string(Map.get(@value_map, "attribute", "max_hp"))}
                >
                  {attr}
                </option>
              <% end %>
            </select>
          <% true -> %>
            <.live_component
              module={GameWeb.FormulaEditorComponent}
              id={"effect-#{@f_nested.id}-#{param}"}
              value={Map.get(@value_map, param, %{})}
              field={"#{@field_base}[#{param}]"}
              path={[]}
              context={:effect}
            />
        <% end %>
      <% end %>
    </fieldset>
    """
  end

  defp list_base_cards do
    Game.BaseCards.list_basecards()
    |> Enum.sort_by(& &1.name)
  end

  @formula_operators MapSet.new(
                       ~w(var == === != !== ! !! if or and > >= < <= max min + - * / % map filter reduce all none some in cat log alias)
                     )

  defp params_map?(map) do
    keys = Map.keys(map)
    length(keys) != 1 or hd(keys) not in @formula_operators
  end
end
