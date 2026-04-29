defmodule GameWeb.Admin.Fields.FormulaField do
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
    <span class="font-mono text-xs"><%= @label %></span>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    value =
      Map.get(assigns, :value) ||
        Phoenix.HTML.Form.input_value(assigns.form, assigns.name) ||
        %{}

    assigns = assign(assigns, :formula_value, value)

    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label}>
          <Layout.input_label text={@field_options[:label]} />
        </:label>
        <.live_component
          module={GameWeb.FormulaEditorComponent}
          id={"formula-#{@form[@name].id}-#{@name}"}
          value={@formula_value}
          field={"#{@form[@name].name}"}
          path={[]}
        />
      </Layout.field_container>
    </div>
    """
  end
end
