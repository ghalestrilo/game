defmodule GameWeb.FormulaEditorTestLive do
  use GameWeb, :live_view
  alias GameWeb.FormulaEditorComponent

  @moduledoc """
  A test LiveView for mounting and testing the FormulaEditor component.
  """

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:formula, "")
      |> assign(:form, to_form(%{"formula" => %{}}))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1 class="text-xl font-bold mb-4">Formula Editor Test</h1>

      <.form for={@form} phx-change="validate" phx-submit="save">
        <div class="mb-4">
          <label class="block text-sm font-medium mb-2">Formula Expression</label>
          <.live_component
            module={FormulaEditorComponent}
            id="formula-editor"
            value={@formula}
            field="formula"
          />
        </div>

        <div class="flex gap-2">
          <button
            type="submit"
            class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
          >
            Save Formula
          </button>
        </div>
      </.form>

      <div class="mt-4 p-4 bg-gray-100 rounded">
        <h2 class="font-bold mb-2">Current Formula:</h2>
        <pre class="text-xs"><%= inspect(@formula, pretty: true) %></pre>
      </div>

      <%= if assigns[:result] do %>
        <div class="mt-4 p-4 bg-green-100 rounded">
          <h2 class="font-bold mb-2">Saved Formula:</h2>
          <pre class="text-xs"><%= inspect(@result, pretty: true) %></pre>
          <pre id="result-json" data-testid="result-json" style="display: none;"><%= Jason.encode!(@result) %></pre>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("validate", params, socket) do
    formula = Game.Formula.parse_params(params["formula"])
    {:noreply, assign(socket, formula: formula)}
  end

  def handle_event("save", params, socket) do
    formula = Game.Formula.parse_params(params["formula"])

    socket =
      socket
      |> assign(:formula, formula)
      |> assign(:result, formula)
      |> put_flash(:info, "Formula saved successfully")

    {:noreply, socket}
  end

  def handle_info({:formula_updated, _root_id, path, new_value}, socket) do
    formula = Game.Formula.update_at_path(socket.assigns.formula, path, new_value)
    {:noreply, assign(socket, formula: formula)}
  end

  def handle_info({:formula_remove_node, _root_id, path}, socket) do
    formula = Game.Formula.remove_at_path(socket.assigns.formula, path)
    {:noreply, assign(socket, formula: formula)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
