defmodule GameWeb.Components.FormulaTreeComponent do
  use Phoenix.LiveComponent

  # Called as a live_component with value= assign
  def render(%{value: _value} = assigns) do
    ~H"""
    <div class="jl-node">
      <.jl_node value={@value} />
    </div>
    """
  end

  # Called as a live_component with "distance" (for "move")
  def render(%{distance: _distance} = assigns) do
    ~H"""
    <div class="jl-node">
      <.jl_node value={@distance} />
    </div>
    """
  end

  # Called directly as render(effect_struct) from core_components — render via protocol label
  def render(assigns) do
    label =
      try do
        Game.Combat.CardEffect.get_value_label(assigns)
      rescue
        _ -> inspect(Map.drop(assigns, [:type, :value_label]))
      end

    assigns = Map.put(assigns, :label, label)

    ~H"""
    <span class="jl-value badge badge-ghost text-xs">{@label}</span>
    """
  end

  # ---------- RECURSIVE NODE COMPONENT ----------

  # alias
  defp jl_node(%{value: %{"alias" => name}} = assigns) do
    ~H"""
    <span class="jl-var badge badge-outline badge-primary">{@value["alias"]}</span>
    """
  end

  # and
  defp jl_node(%{value: %{"and" => _args}} = assigns) do
    ~H"""
    <div class="jl-group jl-and flex flex-col gap-1">
      <span class="jl-label badge badge-soft badge-primary">ALL</span>
      <div class="jl-children flex flex-col gap-1 pl-3 border-l border-primary/30">
        <.jl_node :for={child <- @value["and"]} value={child} />
      </div>
    </div>
    """
  end

  # or
  defp jl_node(%{value: %{"or" => _args}} = assigns) do
    ~H"""
    <div class="jl-group jl-or flex flex-col gap-1">
      <span class="jl-label badge badge-soft badge-secondary">ANY</span>
      <div class="jl-children flex flex-col gap-1 pl-3 border-l border-secondary/30">
        <.jl_node :for={child <- @value["or"]} value={child} />
      </div>
    </div>
    """
  end

  # ! (NOT)
  defp jl_node(%{value: %{"!" => _}} = assigns) do
    ~H"""
    <div class="jl-unary flex items-center gap-1">
      <span class="jl-op badge badge-soft">NOT</span>
      <.jl_node value={@value["!"]} />
    </div>
    """
  end

  # !! (truthy)
  defp jl_node(%{value: %{"!!" => _}} = assigns) do
    ~H"""
    <div class="jl-unary flex items-center gap-1">
      <span class="jl-op badge badge-soft">!!</span>
      <.jl_node value={@value["!!"]} />
    </div>
    """
  end

  # if
  defp jl_node(%{value: %{"if" => args}} = assigns) when is_list(args) do
    # assigns = assign(assigns, :chunks, Enum.chunk_every(args, 2))
    [if_clause, then_clause | rest] = args

    ~H"""
    <div class="jl-if flex flex-col gap-1">
      <div class="jl-if-row flex flex-row items-center gap-1">
        <span class="jl-if-label badge badge-soft badge-warning">IF</span>
        <.jl_node value={if_clause} />
      </div>
      <div class="jl-if-row flex flex-row items-center gap-1">
        <span class="jl-if-label badge badge-soft badge-info">THEN</span>
        <.jl_node value={then_clause} />
      </div>
      <div :if={Enum.at(rest, 0)} class="jl-if-row flex flex-row items-center gap-1">
        <span class="jl-if-label badge badge-soft badge-neutral">ELSE</span>
        <.jl_node value={Enum.at(rest, 0)} />
      </div>
    </div>
    """
  end

  # comparison operators — one clause each (Elixir forbids variable map keys in patterns)
  defp jl_node(%{value: %{"==" => [a, b]}} = assigns), do: jl_binary(assigns, "==", a, b)
  defp jl_node(%{value: %{"===" => [a, b]}} = assigns), do: jl_binary(assigns, "===", a, b)
  defp jl_node(%{value: %{"!=" => [a, b]}} = assigns), do: jl_binary(assigns, "!=", a, b)
  defp jl_node(%{value: %{"!==" => [a, b]}} = assigns), do: jl_binary(assigns, "!==", a, b)
  defp jl_node(%{value: %{">" => [a, b]}} = assigns), do: jl_binary(assigns, ">", a, b)
  defp jl_node(%{value: %{">=" => [a, b]}} = assigns), do: jl_binary(assigns, ">=", a, b)
  defp jl_node(%{value: %{"<" => [a, b]}} = assigns), do: jl_binary(assigns, "<", a, b)
  defp jl_node(%{value: %{"<=" => [a, b]}} = assigns), do: jl_binary(assigns, "<=", a, b)

  defp jl_binary(assigns, op, left, right) do
    assigns = assign(assigns, op: op, left: left, right: right)

    ~H"""
    <div class="jl-binary flex items-center gap-1">
      <.jl_node value={@left} />
      <span class="jl-op badge badge-soft badge-accent">{@op}</span>
      <.jl_node value={@right} />
    </div>
    """
  end

  # arithmetic
  defp jl_node(%{value: %{"+" => args}} = assigns), do: jl_arithmetic(assigns, "+", args)
  defp jl_node(%{value: %{"-" => args}} = assigns), do: jl_arithmetic(assigns, "-", args)
  defp jl_node(%{value: %{"*" => args}} = assigns), do: jl_arithmetic(assigns, "*", args)
  defp jl_node(%{value: %{"/" => args}} = assigns), do: jl_arithmetic(assigns, "/", args)
  defp jl_node(%{value: %{"%" => args}} = assigns), do: jl_arithmetic(assigns, "%", args)

  defp jl_arithmetic(assigns, op, args) do
    args_list = if is_list(args), do: args, else: [args]
    assigns = assign(assigns, op: op, args: args_list)

    ~H"""
    <div class="jl-arith flex items-center gap-1 flex-wrap">
      <%= for {child, i} <- Enum.with_index(@args) do %>
        <.jl_node value={child} />
        <%= if i < length(@args) - 1 do %>
          <span class="jl-op badge badge-soft">{@op}</span>
        <% end %>
      <% end %>
    </div>
    """
  end

  # in (contains)
  defp jl_node(%{value: %{"in" => [needle, haystack]}} = assigns) do
    assigns = assign(assigns, needle: needle, haystack: haystack)

    ~H"""
    <div class="jl-binary flex items-center gap-1">
      <.jl_node value={@needle} />
      <span class="jl-op badge badge-soft">in</span>
      <.jl_node value={@haystack} />
    </div>
    """
  end

  # max, min
  defp jl_node(%{value: %{"max" => args}} = assigns), do: jl_minmax(assigns, "max", args)
  defp jl_node(%{value: %{"min" => args}} = assigns), do: jl_minmax(assigns, "min", args)

  defp jl_minmax(assigns, op, args) do
    args_list = if is_list(args), do: args, else: [args]
    assigns = assign(assigns, op: op, args: args_list)

    ~H"""
    <div class="jl-fn flex items-center gap-1">
      <span class="jl-label badge badge-soft">{@op}</span>
      <.jl_node :for={child <- @args} value={child} />
    </div>
    """
  end

  # cat (string concatenation)
  defp jl_node(%{value: %{"cat" => _}} = assigns) do
    ~H"""
    <div class="jl-fn flex items-center gap-1 flex-wrap">
      <span class="jl-label badge badge-soft">cat</span>
      <.jl_node :for={child <- @value["cat"]} value={child} />
    </div>
    """
  end

  # array ops: map, filter, all, none, some
  defp jl_node(%{value: %{"map" => [arr, f]}} = assigns), do: jl_array_op(assigns, "map", arr, f)

  defp jl_node(%{value: %{"filter" => [arr, f]}} = assigns),
    do: jl_array_op(assigns, "filter", arr, f)

  defp jl_node(%{value: %{"all" => [arr, f]}} = assigns), do: jl_array_op(assigns, "all", arr, f)

  defp jl_node(%{value: %{"none" => [arr, f]}} = assigns),
    do: jl_array_op(assigns, "none", arr, f)

  defp jl_node(%{value: %{"some" => [arr, f]}} = assigns),
    do: jl_array_op(assigns, "some", arr, f)

  defp jl_array_op(assigns, op, arr, formula) do
    assigns = assign(assigns, op: op, arr: arr, formula: formula)

    ~H"""
    <div class="jl-fn flex flex-col gap-1">
      <span class="jl-label badge badge-soft">{@op}</span>
      <div class="pl-3 border-l border-base-content/20 flex flex-col gap-1">
        <.jl_node value={@arr} />
        <.jl_node value={@formula} />
      </div>
    </div>
    """
  end

  # reduce
  defp jl_node(%{value: %{"reduce" => [arr, formula, initial]}} = assigns) do
    assigns = assign(assigns, arr: arr, formula: formula, initial: initial)

    ~H"""
    <div class="jl-fn flex flex-col gap-1">
      <span class="jl-label badge badge-soft">reduce</span>
      <div class="pl-3 border-l border-base-content/20 flex flex-col gap-1">
        <.jl_node value={@arr} />
        <.jl_node value={@formula} />
        <span class="text-xs opacity-50">
          init: <.jl_node value={@initial} />
        </span>
      </div>
    </div>
    """
  end

  # log
  defp jl_node(%{value: %{"log" => _}} = assigns) do
    ~H"""
    <div class="jl-unary flex items-center gap-1">
      <span class="jl-op badge badge-soft badge-neutral">log</span>
      <.jl_node value={@value["log"]} />
    </div>
    """
  end

  # var — string key
  defp jl_node(%{value: %{"var" => key}} = assigns) when is_binary(key) do
    ~H"""
    <span class="jl-var badge badge-outline">{@value["var"]}</span>
    """
  end

  # var — list key (possibly with default)
  defp jl_node(%{value: %{"var" => [key | rest]}} = assigns) do
    assigns = assign(assigns, var_key: key, var_default: List.first(rest))

    ~H"""
    <span class="jl-var badge badge-outline">
      {@var_key}
      <%= if @var_default != nil do %>
        <span class="opacity-50"> ??    {@var_default}</span>
      <% end %>
    </span>
    """
  end

  # empty map
  defp jl_node(%{value: value} = assigns) when is_map(value) and map_size(value) == 0 do
    ~H"""
    <span class="jl-empty opacity-40 text-xs">(empty)</span>
    """
  end

  # unknown single-key operator — generic fallback
  defp jl_node(%{value: value} = assigns) when is_map(value) and map_size(value) == 1 do
    [{op, raw_args}] = Map.to_list(value)
    args_list = if is_list(raw_args), do: raw_args, else: [raw_args]
    assigns = assign(assigns, op: op, args: args_list)

    ~H"""
    <div class="jl-unknown flex flex-col gap-1">
      <span class="jl-label badge badge-soft badge-error">{@op}</span>
      <div class="jl-children flex flex-col gap-1 pl-3 border-l border-error/30">
        <.jl_node :for={child <- @args} value={child} />
      </div>
    </div>
    """
  end

  # list of values
  defp jl_node(%{value: value} = assigns) when is_list(value) do
    assigns = assign(assigns, :items, Enum.map(value, &inspect/1))

    ~H"""
    <span class="jl-list text-xs opacity-70">[{Enum.join(@items, ", ")}]</span>
    """
  end

  # primitive: string
  defp jl_node(%{value: value} = assigns) when is_binary(value) do
    ~H"""
    <span class="jl-value badge badge-ghost text-xs">"{@value}"</span>
    """
  end

  # primitive: number or boolean
  defp jl_node(%{value: value} = assigns) when is_number(value) or is_boolean(value) do
    ~H"""
    <span class="jl-value badge badge-ghost text-xs">{inspect(@value)}</span>
    """
  end

  # nil / unknown
  defp jl_node(%{value: _value} = assigns) do
    ~H"""
    <span class="jl-value text-xs opacity-60">{inspect(@value)}</span>
    """
  end
end
