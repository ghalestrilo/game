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
      "var" -> %{arity: :variable, args: [:string_or_number], description: "Get variable value", min_args: 1, max_args: 2}
      "==" -> %{arity: 2, args: [:any, :any], description: "Equal (loose)"}
      "===" -> %{arity: 2, args: [:any, :any], description: "Equal (strict)"}
      "!=" -> %{arity: 2, args: [:any, :any], description: "Not equal (loose)"}
      "!==" -> %{arity: 2, args: [:any, :any], description: "Not equal (strict)"}
      "!" -> %{arity: 1, args: [:any], description: "Logical NOT"}
      "!!" -> %{arity: 1, args: [:any], description: "Truthy"}
      "if" -> %{arity: :variable, args: [:any], description: "If-then-else", min_args: 3}
      "or" -> %{arity: :variable, args: [:any], description: "Logical OR", min_args: 1}
      "and" -> %{arity: :variable, args: [:any], description: "Logical AND", min_args: 1}
      ">" -> %{arity: :variable, args: [:number], description: "Greater than", min_args: 2}
      ">=" -> %{arity: :variable, args: [:number], description: "Greater than or equal", min_args: 2}
      "<" -> %{arity: :variable, args: [:number], description: "Less than", min_args: 2}
      "<=" -> %{arity: :variable, args: [:number], description: "Less than or equal", min_args: 2}
      "max" -> %{arity: :variable, args: [:number], description: "Maximum value", min_args: 1}
      "min" -> %{arity: :variable, args: [:number], description: "Minimum value", min_args: 1}
      "+" -> %{arity: :variable, args: [:number], description: "Addition", min_args: 1}
      "-" -> %{arity: :variable, args: [:number], description: "Subtraction", min_args: 1}
      "*" -> %{arity: :variable, args: [:number], description: "Multiplication", min_args: 1}
      "/" -> %{arity: 2, args: [:number, :number], description: "Division"}
      "%" -> %{arity: 2, args: [:number, :number], description: "Modulo"}
      "map" -> %{arity: 2, args: [:array, :formula], description: "Map over array"}
      "filter" -> %{arity: 2, args: [:array, :formula], description: "Filter array"}
      "reduce" -> %{arity: 3, args: [:array, :formula, :any], description: "Reduce array"}
      "all" -> %{arity: 2, args: [:array, :formula], description: "All elements match"}
      "none" -> %{arity: 2, args: [:array, :formula], description: "No elements match"}
      "some" -> %{arity: 2, args: [:array, :formula], description: "Some elements match"}
      "in" -> %{arity: 2, args: [:any, :array_or_string], description: "Contains"}
      "cat" -> %{arity: :variable, args: [:any], description: "Concatenate strings", min_args: 1}
      "log" -> %{arity: 1, args: [:any], description: "Log value"}
      _ -> %{arity: 0, args: [], description: "Unknown operator"}
    end
  end
end
