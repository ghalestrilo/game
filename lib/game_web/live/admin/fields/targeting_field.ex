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
        targeting_mode: Map.get(targeting, "mode", "null"),
        targeting_rule: Map.get(targeting, "rule", %{})
      )

    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label}>
          <Layout.input_label text={@field_options[:label]} />
        </:label>
        <div class="flex flex-col gap-2 p-2 border border-base-300 rounded">
          <div class="flex gap-2">
            <select name={"#{@form[@name].name}[type]"} class="select select-sm w-40">
              <option value="character" selected={@targeting_type == "character"}>Character</option>
              <option value="tile" selected={@targeting_type == "tile"}>Tile</option>
            </select>
            <select name={"#{@form[@name].name}[mode]"} class="select select-sm w-40">
              <option value="null" selected={@targeting_mode == "null"}>Null (any)</option>
              <option value="linear" selected={@targeting_mode == "linear"}>Linear (LOS)</option>
              <option value="guided" selected={@targeting_mode == "guided"}>Guided (A*)</option>
              <option value="area" selected={@targeting_mode == "area"}>Area</option>
              <option value="emanation" selected={@targeting_mode == "emanation"}>Emanation</option>
            </select>
          </div>
          <p class="text-xs font-medium text-base-content/50 uppercase tracking-wide">Rule</p>
          <.live_component
            module={GameWeb.FormulaEditorComponent}
            id={"targeting-rule-#{@form[@name].id}"}
            value={@targeting_rule}
            field={"#{@form[@name].name}[rule]"}
            path={[]}
            context={:targeting}
          />
        </div>
      </Layout.field_container>
    </div>
    """
  end
end
