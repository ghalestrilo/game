defmodule GameWeb.FormulaEditorTestLive do
  use GameWeb, :live_view
  alias GameWeb.FormulaEditorComponent

  @moduledoc """
  A test LiveView for mounting and testing the FormulaEditor component.
  """

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:formula, %{})
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
    formula = parse_formula_from_params(params["formula"])
    {:noreply, assign(socket, formula: formula)}
  end

  def handle_event("save", params, socket) do
    formula = parse_formula_from_params(params["formula"])

    socket =
      socket
      |> assign(:formula, formula)
      |> assign(:result, formula)
      |> put_flash(:info, "Formula saved successfully")

    {:noreply, socket}
  end

  def handle_info({:formula_updated, path, new_value}, socket) do
    formula = update_formula_at_path(socket.assigns.formula, path, new_value)
    {:noreply, assign(socket, formula: formula)}
  end

  def handle_info({:formula_remove_node, path}, socket) do
    formula = remove_node_at_path(socket.assigns.formula, path)
    {:noreply, assign(socket, formula: formula)}
  end

  # Parse formula from form params (nested structure)
  defp parse_formula_from_params(nil), do: %{}

  defp parse_formula_from_params(params) when is_map(params) do
    case params do
      %{"operator" => ""} ->
        %{}

      %{"operator" => op} when is_binary(op) ->
        # Collect arguments
        args = collect_args_from_params(params, 0, [])
        if args == [], do: %{}, else: %{op => args}

      %{"value" => value} ->
        parse_value(value)

      _ ->
        %{}
    end
  end

  defp collect_args_from_params(params, index, acc) do
    case params[to_string(index)] do
      nil ->
        Enum.reverse(acc)

      arg_params ->
        parsed = parse_formula_from_params(arg_params)
        collect_args_from_params(params, index + 1, [parsed | acc])
    end
  end

  defp parse_value(value) when is_binary(value) do
    cond do
      value == "" -> ""
      String.match?(value, ~r/^-?\d+$/) -> String.to_integer(value)
      String.match?(value, ~r/^-?\d+\.\d+$/) -> String.to_float(value)
      true -> value
    end
  end

  defp parse_value(value), do: value

  # Update formula at a specific path
  defp update_formula_at_path(_formula, [], new_value), do: new_value

  defp update_formula_at_path(formula, [index | rest], new_value) when is_map(formula) do
    [{op, args}] = Map.to_list(formula)
    args_list = if is_list(args), do: args, else: [args]

    updated_args =
      List.update_at(args_list, index, fn arg ->
        update_formula_at_path(arg, rest, new_value)
      end)

    %{op => updated_args}
  end

  # Remove node at a specific path
  defp remove_node_at_path(_formula, []), do: %{}

  defp remove_node_at_path(formula, [index | rest]) when is_map(formula) do
    if rest == [] do
      # Remove this argument
      [{op, args}] = Map.to_list(formula)
      args_list = if is_list(args), do: args, else: [args]
      updated_args = List.delete_at(args_list, index)

      if updated_args == [], do: %{}, else: %{op => updated_args}
    else
      # Navigate deeper
      [{op, args}] = Map.to_list(formula)
      args_list = if is_list(args), do: args, else: [args]

      updated_args =
        List.update_at(args_list, index, fn arg ->
          remove_node_at_path(arg, rest)
        end)

      %{op => updated_args}
    end
  end
end
