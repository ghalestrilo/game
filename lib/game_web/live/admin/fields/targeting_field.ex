defmodule GameWeb.Admin.Fields.TargetingField do
  use Backpex.Field

  @impl Backpex.Field
  def render_value(assigns) do
    ~H"""
    <div>
      <span :if={@value} class="badge badge-sm">{@value["type"]}</span>
    </div>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    targeting =
      Map.get(assigns, :value) ||
        Phoenix.HTML.Form.input_value(assigns.form, assigns.name) ||
        %{}

    assigns =
      assign(assigns,
        targeting_type: Map.get(targeting, "type", "character"),
        targeting_rule: Map.get(targeting, "rule", %{})
      )

    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label}>
          <Layout.input_label text={@field_options[:label]} />
        </:label>
        <div class="flex flex-col gap-2 p-2 border border-base-300 rounded">
          <select name={"#{@form[@name].name}[type]"} class="select select-sm w-40">
            <option value="character" selected={@targeting_type == "character"}>Character</option>
            <option value="tile" selected={@targeting_type == "tile"}>Tile</option>
          </select>
          <p class="text-xs font-medium text-base-content/50 uppercase tracking-wide">Rule</p>
          <.live_component
            module={GameWeb.FormulaEditorComponent}
            id={"targeting-rule-#{@form[@name].id}"}
            value={@targeting_rule}
            field={"#{@form[@name].name}[rule]"}
            path={[]}
          />
        </div>
      </Layout.field_container>
    </div>
    """
  end
end
