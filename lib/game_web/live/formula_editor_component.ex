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
    is_root = Map.get(assigns, :path, []) == []

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:path, fn -> [] end)
      |> assign_new(:value, fn -> "" end)
      |> assign_new(:root_id, fn -> assigns.id end)
      |> assign_new(:root_value, fn -> assigns[:value] || "" end)
      |> assign_new(:aliases, fn -> Formula.available_aliases() end)
      |> assign_new(:variables, fn -> Formula.available_variables(assigns[:context]) end)
      |> then(fn s ->
        if is_root, do: assign(s, :root_value, s.assigns.value), else: s
      end)
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
    <div class="formula-editor-node border border-base-300 rounded p-3 mb-2 bg-base-100">
      <div class="flex items-start gap-2">
        <div class="flex-grow">
          <%= if @args != [] and is_nil(@operator) do %>
            <%!-- Literal mode: plain value with option to switch to formula --%>
            <div class="flex gap-2 items-center">
              <input
                type="text"
                name={build_field_name(@field || "formula", @path, "value")}
                value={to_string(List.first(@args))}
                placeholder="Literal value"
                class="border border-base-300 rounded px-3 py-2 text-sm flex-1 bg-base-100 text-base-content"
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
          <% else %>
            <%!-- Formula mode: operator dropdown (possibly with no operator selected yet) --%>
            <div class="flex items-center gap-2">
              <.operator_select
                path={@path}
                operator={@operator}
                field_name={@field || "formula"}
                myself={@myself}
                aliases={@aliases}
              />
              <button
                type="button"
                phx-click="convert_to_value"
                phx-target={@myself}
                class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 border border-base-300 rounded"
                title="Convert to simple value"
              >
                123
              </button>
              <%= if @path != [] do %>
                <button
                  type="button"
                  phx-click="remove_node"
                  phx-target={@myself}
                  class="text-red-600 hover:text-red-800 text-sm px-2"
                  title="Remove"
                >
                  ✕
                </button>
              <% end %>
            </div>

            <%= if @operator do %>
              <div class="ml-4 mt-2 space-y-2">
                <%= for {arg, idx} <- Enum.with_index(@args) do %>
                  <div class="formula-arg border-l-2 border-blue-300 pl-3 flex items-start gap-2">
                    <div class="flex-1">
                      <.arg_editor
                        arg={arg}
                        operator={@operator}
                        arg_index={idx}
                        path={@path ++ [idx]}
                        field={@field || "formula"}
                        id={"#{@id}-arg-#{idx}"}
                        myself={@myself}
                        root_id={@root_id}
                        root_value={@root_value}
                        aliases={@aliases}
                        variables={@variables}
                      />
                    </div>
                    <button
                      :if={can_remove_arg?(@operator, @args)}
                      type="button"
                      phx-click="remove_arg"
                      phx-value-path={Jason.encode!(@path ++ [idx])}
                      phx-target={@myself}
                      class="text-base-content/40 hover:text-red-500 px-1 py-2"
                      title="Remove argument"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                <% end %>

                <button
                  :if={can_add_arg?(@operator, @args)}
                  type="button"
                  phx-click="add_arg"
                  phx-target={@myself}
                  class="text-sm text-blue-600 hover:text-blue-800"
                >
                  + Add argument
                </button>
              </div>
            <% end %>
          <% end %>
        </div>
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
      class="border border-base-300 rounded px-3 py-2 text-sm bg-base-100 text-base-content"
    >
      <option value="">-- Select operator --</option>
      <%= for op <- list_available_keywords() do %>
        <option value={op} selected={op == @operator}>
          {op} - {Formula.operator_metadata(op).description}
        </option>
      <% end %>
    </select>
    """
  end

  defp arg_editor(assigns) do
    metadata = Formula.operator_metadata(assigns.operator)
    is_formula_arg = metadata.args |> Enum.at(assigns.arg_index) == :formula
    is_var_operator = assigns.operator == "var"
    is_alias_operator = assigns.operator == "alias"
    is_nested_map = is_map(assigns.arg)
    has_variables = assigns.variables != []

    cond do
      # For var operator with known context: dropdown of available variable paths
      is_var_operator and has_variables ->
        ~H"""
        <select
          name={build_field_name(@field, @path, "value")}
          class="border border-base-300 rounded px-3 py-2 text-sm bg-base-100 text-base-content"
        >
          <option value="">-- Select variable --</option>
          <%= for var <- @variables do %>
            <option value={var.name} selected={var.name == @arg}>
              {var.name}
              <%= if var.description do %>
                - {var.description}
              <% end %>
            </option>
          <% end %>
        </select>
        """

      # For var operator without context: free text fallback
      is_var_operator ->
        ~H"""
        <input
          type="text"
          name={build_field_name(@field, @path, "value")}
          value={@arg}
          placeholder="Variable name"
          class="border border-base-300 rounded px-3 py-2 text-sm w-full bg-base-100 text-base-content"
        />
        """

      # For alias operator, show a dropdown of available alias names
      is_alias_operator ->
        ~H"""
        <select
          name={build_field_name(@field, @path, "value")}
          class="border border-base-300 rounded px-3 py-2 text-sm bg-base-100 text-base-content"
        >
          <option value="">-- Select alias --</option>
          <%= for alias_entry <- @aliases do %>
            <option value={alias_entry.name} selected={alias_entry.name == @arg}>
              {alias_entry.name}
              <%= if alias_entry.description do %>
                - {alias_entry.description}
              <% end %>
            </option>
          <% end %>
        </select>
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
          root_id={@root_id}
          root_value={@root_value}
          aliases={@aliases}
          variables={@variables}
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
            class="border border-base-300 rounded px-3 py-2 text-sm flex-1 bg-base-100 text-base-content"
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
    operator = extract_operator_value(params, socket.assigns.field, socket.assigns.path)

    new_node =
      if operator == "" do
        %{}
      else
        metadata = Formula.operator_metadata(operator)
        min_args = Map.get(metadata, :min_args, metadata.arity)

        default_args =
          case min_args do
            n when is_integer(n) -> List.duplicate("", n)
            :variable -> [""]
          end

        %{operator => default_args}
      end

    push_root_update(socket, socket.assigns.path, new_node)
    {:noreply, socket}
  end

  def handle_event("add_arg", _params, socket) do
    new_node = %{socket.assigns.operator => socket.assigns.args ++ [""]}
    push_root_update(socket, socket.assigns.path, new_node)
    {:noreply, socket}
  end

  def handle_event("remove_node", _params, socket) do
    new_root = Formula.remove_at_path(socket.assigns.root_value, socket.assigns.path)
    Phoenix.LiveView.send_update(__MODULE__, id: socket.assigns.root_id, value: new_root)
    {:noreply, socket}
  end

  def handle_event("convert_to_formula", %{"path" => path_json}, socket) do
    path = Jason.decode!(path_json)
    push_root_update(socket, path, %{})
    {:noreply, socket}
  end

  def handle_event("remove_arg", %{"path" => path_json}, socket) do
    path = Jason.decode!(path_json)
    new_root = Formula.remove_at_path(socket.assigns.root_value, path)
    Phoenix.LiveView.send_update(__MODULE__, id: socket.assigns.root_id, value: new_root)
    {:noreply, socket}
  end

  def handle_event("convert_to_value", _params, socket) do
    push_root_update(socket, socket.assigns.path, "")
    {:noreply, socket}
  end

  defp push_root_update(socket, [], new_node) do
    Phoenix.LiveView.send_update(__MODULE__, id: socket.assigns.root_id, value: new_node)
  end

  defp push_root_update(socket, path, new_node) do
    new_root = Formula.update_at_path(socket.assigns.root_value, path, new_node)
    Phoenix.LiveView.send_update(__MODULE__, id: socket.assigns.root_id, value: new_root)
  end

  @doc """
  Returns a list of all available formula keywords/operators.
  """
  def list_available_keywords do
    Formula.available_operators()
  end

  # Private helper functions

  defp can_remove_arg?(operator, args) do
    %{arity: arity} = metadata = Formula.operator_metadata(operator)
    min = Map.get(metadata, :min_args, arity)

    case min do
      n when is_integer(n) -> length(args) > n
      _ -> false
    end
  end

  defp can_add_arg?(operator, args) do
    %{arity: arity} = metadata = Formula.operator_metadata(operator)

    case arity do
      n when is_integer(n) -> length(args) < n
      :variable -> length(args) < Map.get(metadata, :max_args, :infinity)
    end
  end

  defp extract_operator_value(%{"value" => operator}, _field, _path) when is_binary(operator),
    do: operator

  defp extract_operator_value(params, field, path) do
    # The browser sends a full nested params map keyed by the bracket-notation field
    # name, e.g. field = "change[effects][0][value]" arrives as nested maps:
    # %{"change" => %{"effects" => %{"0" => %{"value" => %{"operator" => ">"}}}}}
    # Parse the bracket path into a list of string keys, append index path and "operator".
    field_keys = Regex.scan(~r/([^\[\]]+)/, field, capture: :all_but_first) |> List.flatten()
    index_keys = Enum.map(path, &to_string/1)
    full_path = field_keys ++ index_keys ++ ["operator"]
    get_in(params, full_path) || ""
  end
end
