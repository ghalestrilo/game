defmodule Game.Formula do
  @moduledoc """
  A thin wrapper around JsonLogic for formula evaluation.
  Provides a consistent API for working with formula expressions in the game.
  """

  @doc """
  Resolves a formula expression with the given data context.
  Delegates directly to JsonLogic.resolve/2.

  ## Examples

      iex> Game.Formula.resolve(%{"var" => "hp"}, %{"hp" => 10})
      10

      iex> Game.Formula.resolve(%{">" => [%{"var" => "hp"}, 5]}, %{"hp" => 10})
      true
  """
  @spec resolve(map() | nil, map() | nil) :: term()
  defdelegate resolve(logic, data \\ nil), to: JsonLogic

  @doc """
  Returns a list of all available formula operators/keywords.
  """
  @spec available_operators() :: list(String.t())
  def available_operators do
    [
      # Variables
      "var",
      # Logic
      "==",
      "===",
      "!=",
      "!==",
      "!",
      "!!",
      "if",
      "or",
      "and",
      # Numeric
      ">",
      ">=",
      "<",
      "<=",
      "max",
      "min",
      "+",
      "-",
      "*",
      "/",
      "%",
      # Array operations
      "map",
      "filter",
      "reduce",
      "all",
      "none",
      "some",
      # String operations
      "in",
      "cat",
      # Other
      "log"
    ]
  end

  @doc """
  Returns metadata about an operator including its arity and argument types.
  """
  @spec operator_metadata(String.t()) :: map()
  def operator_metadata(operator) do
    case operator do
      "var" ->
        %{
          arity: :variable,
          args: [:string_or_number],
          description: "Get variable value",
          min_args: 1,
          max_args: 2
        }

      "==" ->
        %{arity: 2, args: [:any, :any], description: "Equal (loose)"}

      "===" ->
        %{arity: 2, args: [:any, :any], description: "Equal (strict)"}

      "!=" ->
        %{arity: 2, args: [:any, :any], description: "Not equal (loose)"}

      "!==" ->
        %{arity: 2, args: [:any, :any], description: "Not equal (strict)"}

      "!" ->
        %{arity: 1, args: [:any], description: "Logical NOT"}

      "!!" ->
        %{arity: 1, args: [:any], description: "Truthy"}

      "if" ->
        %{arity: :variable, args: [:any], description: "If-then-else", min_args: 3}

      "or" ->
        %{arity: :variable, args: [:any], description: "Logical OR", min_args: 1}

      "and" ->
        %{arity: :variable, args: [:any], description: "Logical AND", min_args: 1}

      ">" ->
        %{arity: :variable, args: [:number], description: "Greater than", min_args: 2}

      ">=" ->
        %{arity: :variable, args: [:number], description: "Greater than or equal", min_args: 2}

      "<" ->
        %{arity: :variable, args: [:number], description: "Less than", min_args: 2}

      "<=" ->
        %{arity: :variable, args: [:number], description: "Less than or equal", min_args: 2}

      "max" ->
        %{arity: :variable, args: [:number], description: "Maximum value", min_args: 1}

      "min" ->
        %{arity: :variable, args: [:number], description: "Minimum value", min_args: 1}

      "+" ->
        %{arity: :variable, args: [:number], description: "Addition", min_args: 1}

      "-" ->
        %{arity: :variable, args: [:number], description: "Subtraction", min_args: 1}

      "*" ->
        %{arity: :variable, args: [:number], description: "Multiplication", min_args: 2}

      "/" ->
        %{arity: 2, args: [:number, :number], description: "Division"}

      "%" ->
        %{arity: 2, args: [:number, :number], description: "Modulo"}

      "map" ->
        %{arity: 2, args: [:array, :formula], description: "Map over array"}

      "filter" ->
        %{arity: 2, args: [:array, :formula], description: "Filter array"}

      "reduce" ->
        %{arity: 3, args: [:array, :formula, :any], description: "Reduce array"}

      "all" ->
        %{arity: 2, args: [:array, :formula], description: "All elements match"}

      "none" ->
        %{arity: 2, args: [:array, :formula], description: "No elements match"}

      "some" ->
        %{arity: 2, args: [:array, :formula], description: "Some elements match"}

      "in" ->
        %{arity: 2, args: [:any, :array_or_string], description: "Contains"}

      "cat" ->
        %{arity: :variable, args: [:any], description: "Concatenate strings", min_args: 1}

      "log" ->
        %{arity: 1, args: [:any], description: "Log value"}

      _ ->
        %{arity: 0, args: [], description: "Unknown operator"}
    end
  end

  @doc """
  Parses nested form params from FormulaEditorComponent into a JsonLogic map.

  Input shape (from form submission):
    %{"operator" => "and", "0" => %{"operator" => "var", "0" => %{"value" => "target.occupied"}}}

  Output shape (JsonLogic):
    %{"and" => [%{"var" => ["target.occupied"]}]}
  """
  @spec parse_params(map() | nil) :: map() | String.t() | number()
  def parse_params(nil), do: %{}

  def parse_params(params) when is_map(params) do
    case params do
      %{"operator" => ""} ->
        %{}

      %{"operator" => op} when is_binary(op) ->
        args = collect_args(params, 0, [])
        if args == [], do: %{}, else: %{op => args}

      %{"value" => value} ->
        parse_value(value)

      _ ->
        %{}
    end
  end

  defp collect_args(params, index, acc) do
    case params[to_string(index)] do
      nil -> Enum.reverse(acc)
      arg_params -> collect_args(params, index + 1, [parse_params(arg_params) | acc])
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

  @doc "Updates the formula tree node at the given path index list."
  @spec update_at_path(map(), list(), any()) :: map()
  def update_at_path(_formula, [], new_value), do: new_value

  def update_at_path(formula, [index | rest], new_value) when is_map(formula) do
    [{op, args}] = Map.to_list(formula)
    args_list = if is_list(args), do: args, else: [args]

    updated_args =
      List.update_at(args_list, index, &update_at_path(&1, rest, new_value))

    %{op => updated_args}
  end

  @doc "Removes the formula tree node at the given path index list."
  @spec remove_at_path(map(), list()) :: map()
  def remove_at_path(_formula, []), do: %{}

  def remove_at_path(formula, [index | rest]) when is_map(formula) do
    [{op, args}] = Map.to_list(formula)
    args_list = if is_list(args), do: args, else: [args]

    updated_args =
      if rest == [] do
        List.delete_at(args_list, index)
      else
        List.update_at(args_list, index, &remove_at_path(&1, rest))
      end

    if updated_args == [], do: %{}, else: %{op => updated_args}
  end
end
