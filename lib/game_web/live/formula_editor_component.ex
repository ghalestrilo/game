defmodule GameWeb.FormulaEditorComponent do
  use GameWeb, :live_component
  alias Game.Formula

  @moduledoc """
  A recursive LiveComponent for editing JsonLogic formula expressions.
  Renders a tree of operators and arguments with dropdowns and appropriate input fields.
  """

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:path, fn -> [] end)
      |> assign_new(:value, fn -> %{} end)
      |> assign_operator_and_args()

    {:ok, socket}
  end

  defp assign_operator_and_args(socket) do
    value = socket.assigns.value

    {operator, args} =
      cond do
        is_map(value) and map_size(value) == 1 ->
          [{op, arg_value}] = Map.to_list(value)
          args_list = if is_list(arg_value), do: arg_value, else: [arg_value]
          {op, args_list}

        is_map(value) and map_size(value) == 0 ->
          {nil, []}

        true ->
          {nil, [value]}
      end

    socket
    |> assign(:operator, operator)
    |> assign(:args, args)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="formula-editor-node border border-gray-300 rounded p-3 mb-2 bg-white">
      <div class="flex items-start gap-2">
        <div class="flex-grow">
          <.operator_select
            path={@path}
            operator={@operator}
            field_name={@field || "formula"}
            myself={@myself}
          />

          <%= if @operator do %>
            <div class="ml-4 mt-2 space-y-2">
              <%= for {arg, idx} <- Enum.with_index(@args) do %>
                <div class="formula-arg border-l-2 border-blue-300 pl-3">
                  <.arg_editor
                    arg={arg}
                    operator={@operator}
                    arg_index={idx}
                    path={@path ++ [idx]}
                    field={@field || "formula"}
                    id={"#{@id}-arg-#{idx}"}
                    myself={@myself}
                  />
                </div>
              <% end %>

              <button
                type="button"
                phx-click="add_arg"
                phx-target={@myself}
                class="text-sm text-blue-600 hover:text-blue-800"
              >
                + Add argument
              </button>
            </div>
          <% end %>
        </div>

        <%= if @path != [] do %>
          <div class="flex gap-1">
            <button
              type="button"
              phx-click="convert_to_value"
              phx-target={@myself}
              class="text-xs text-gray-600 hover:text-gray-800 px-2 py-1 border border-gray-300 rounded"
              title="Convert to simple value"
            >
              123
            </button>
            <button
              type="button"
              phx-click="remove_node"
              phx-target={@myself}
              class="text-red-600 hover:text-red-800 text-sm px-2"
              title="Remove"
            >
              ✕
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp operator_select(assigns) do
    ~H"""
    <select
      name={build_field_name(@field_name, @path, "operator")}
      phx-change="change_operator"
      phx-target={@myself}
      class="border border-gray-300 rounded px-3 py-2 text-sm"
    >
      <option value="">-- Select operator --</option>
      <%= for op <- list_available_keywords() do %>
        <option value={op} selected={op == @operator}>
          <%= op %> - <%= Formula.operator_metadata(op).description %>
        </option>
      <% end %>
    </select>
    """
  end

  defp arg_editor(assigns) do
    metadata = Formula.operator_metadata(assigns.operator)
    is_formula_arg = metadata.args |> Enum.at(assigns.arg_index) == :formula
    is_var_operator = assigns.operator == "var"
    is_nested_map = is_map(assigns.arg)

    cond do
      # For var operator, show string input for variable name (special case, can't be nested)
      is_var_operator ->
        ~H"""
        <input
          type="text"
          name={build_field_name(@field, @path, "value")}
          value={@arg}
          placeholder="Variable name"
          class="border border-gray-300 rounded px-3 py-2 text-sm w-full"
        />
        """

      # For all other operators, allow arguments to be either simple values or nested formulas
      # If arg is a map (nested formula), render recursively with operator dropdown
      is_nested_map or is_formula_arg ->
        ~H"""
        <.live_component
          module={__MODULE__}
          id={@id}
          value={@arg}
          path={@path}
          field={@field}
        />
        """

      # For simple values, show a toggle to allow conversion to formula
      true ->
        ~H"""
        <div class="flex gap-2 items-start">
          <input
            type="text"
            name={build_field_name(@field, @path, "value")}
            value={to_string(@arg)}
            placeholder={arg_placeholder(@operator, @arg_index)}
            class="border border-gray-300 rounded px-3 py-2 text-sm flex-1"
          />
          <button
            type="button"
            phx-click="convert_to_formula"
            phx-value-path={Jason.encode!(@path)}
            phx-target={@myself}
            class="text-xs text-blue-600 hover:text-blue-800 px-2 py-1 border border-blue-300 rounded whitespace-nowrap"
            title="Convert to formula"
          >
            ƒx
          </button>
        </div>
        """
    end
  end

  defp build_field_name(base, path, suffix) do
    path_str = Enum.map_join(path, "", fn idx -> "[#{idx}]" end)
    "#{base}#{path_str}[#{suffix}]"
  end

  defp arg_placeholder(operator, index) do
    metadata = Formula.operator_metadata(operator)
    arg_type = Enum.at(metadata.args, index, :any)

    case arg_type do
      :number -> "Enter number"
      :string -> "Enter text"
      :array -> "Enter array"
      _ -> "Enter value"
    end
  end

  @impl true
  def handle_event("change_operator", params, socket) do
    # Extract operator value from params - could be %{"value" => op} or nested form params
    operator = extract_operator_value(params, socket.assigns.field, socket.assigns.path)

    new_value =
      if operator == "" do
        %{}
      else
        metadata = Formula.operator_metadata(operator)
        min_args = Map.get(metadata, :min_args, metadata.arity)

        default_args =
          case min_args do
            n when is_integer(n) -> List.duplicate("", n)
            :variable -> [""]
            _ -> []
          end

        %{operator => default_args}
      end

    send(self(), {:formula_updated, socket.assigns.path, new_value})
    {:noreply, socket}
  end

  def handle_event("add_arg", _params, socket) do
    new_args = socket.assigns.args ++ [""]
    new_value = %{socket.assigns.operator => new_args}
    send(self(), {:formula_updated, socket.assigns.path, new_value})
    {:noreply, socket}
  end

  def handle_event("remove_node", _params, socket) do
    send(self(), {:formula_remove_node, socket.assigns.path})
    {:noreply, socket}
  end

  def handle_event("convert_to_formula", %{"path" => path_json}, socket) do
    path = Jason.decode!(path_json)
    # Send message to parent to convert the value at this path to an empty formula
    send(self(), {:formula_updated, path, %{}})
    {:noreply, socket}
  end

  def handle_event("convert_to_value", _params, socket) do
    # Convert the current formula node back to a simple empty string value
    send(self(), {:formula_updated, socket.assigns.path, ""})
    {:noreply, socket}
  end

  @doc """
  Returns a list of all available formula keywords/operators.
  """
  def list_available_keywords do
    Formula.available_operators()
  end

  # Private helper functions

  defp extract_operator_value(%{"value" => operator}, _field, _path), do: operator
  defp extract_operator_value(params, field, path) do
    # Navigate through nested params structure
    # For root: %{"formula" => %{"operator" => ">"}}
    # For nested: %{"formula" => %{"0" => %{"operator" => "var"}}}
    value = get_in(params, [field | Enum.map(path, &to_string/1)] ++ ["operator"])
    value || ""
  end
end
