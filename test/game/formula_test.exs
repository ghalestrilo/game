defmodule Game.FormulaTest do
  use ExUnit.Case, async: true
  alias Game.Formula

  describe "resolve/2" do
    test "delegates to JsonLogic.resolve/2" do
      assert Formula.resolve(%{"var" => "key"}, %{"key" => "value"}) == "value"
    end

    test "resolves simple variable lookup" do
      assert Formula.resolve(%{"var" => "hp"}, %{"hp" => 10}) == 10
    end

    test "resolves comparison operators" do
      assert Formula.resolve(%{">" => [10, 5]}) == true
      assert Formula.resolve(%{"<" => [10, 5]}) == false
      assert Formula.resolve(%{">=" => [10, 10]}) == true
      assert Formula.resolve(%{"<=" => [5, 10]}) == true
    end

    test "resolves equality operators" do
      assert Formula.resolve(%{"==" => [1, 1]}) == true
      assert Formula.resolve(%{"==" => [1, "1"]}) == true
      assert Formula.resolve(%{"===" => [1, 1]}) == true
      assert Formula.resolve(%{"===" => [1, "1"]}) == false
      assert Formula.resolve(%{"!=" => [1, 2]}) == true
      assert Formula.resolve(%{"!==" => [1, "1"]}) == true
    end

    test "resolves logical operators" do
      assert Formula.resolve(%{"and" => [true, true]}) == true
      assert Formula.resolve(%{"and" => [true, false]}) == false
      assert Formula.resolve(%{"or" => [false, true]}) == true
      assert Formula.resolve(%{"or" => [false, false]}) == false
      assert Formula.resolve(%{"!" => true}) == false
      assert Formula.resolve(%{"!" => false}) == true
    end

    test "resolves arithmetic operators" do
      assert Formula.resolve(%{"+" => [1, 2, 3]}) == 6
      assert Formula.resolve(%{"-" => [10, 3]}) == 7
      assert Formula.resolve(%{"*" => [2, 3, 4]}) == 24
      assert Formula.resolve(%{"/" => [10, 2]}) == 5.0
      assert Formula.resolve(%{"%" => [10, 3]}) == 1
    end

    test "resolves nested formulas" do
      formula = %{
        ">" => [
          %{"var" => "hp"},
          5
        ]
      }

      assert Formula.resolve(formula, %{"hp" => 10}) == true
      assert Formula.resolve(formula, %{"hp" => 3}) == false
    end

    test "resolves complex nested formulas" do
      formula = %{
        "and" => [
          %{">" => [%{"var" => "hp"}, 0]},
          %{"==" => [%{"var" => "team"}, "ally"]}
        ]
      }

      assert Formula.resolve(formula, %{"hp" => 10, "team" => "ally"}) == true
      assert Formula.resolve(formula, %{"hp" => 10, "team" => "enemy"}) == false
      assert Formula.resolve(formula, %{"hp" => 0, "team" => "ally"}) == false
    end
  end

  describe "available_operators/0" do
    test "returns a list of operator strings" do
      operators = Formula.available_operators()

      assert is_list(operators)
      assert length(operators) > 0
      assert Enum.all?(operators, &is_binary/1)
    end

    test "includes common operators" do
      operators = Formula.available_operators()

      assert "var" in operators
      assert "==" in operators
      assert ">" in operators
      assert "and" in operators
      assert "or" in operators
      assert "+" in operators
      assert "-" in operators
      assert "if" in operators
    end

    test "includes array operators" do
      operators = Formula.available_operators()

      assert "map" in operators
      assert "filter" in operators
      assert "reduce" in operators
      assert "all" in operators
      assert "some" in operators
      assert "none" in operators
    end

    test "includes string operators" do
      operators = Formula.available_operators()

      assert "in" in operators
      assert "cat" in operators
    end
  end

  describe "operator_metadata/1" do
    test "returns metadata for var operator" do
      metadata = Formula.operator_metadata("var")

      assert metadata.arity == :variable
      assert metadata.args == [:string_or_number]
      assert is_binary(metadata.description)
    end

    test "returns metadata for comparison operators" do
      metadata = Formula.operator_metadata(">")

      assert metadata.arity == :variable
      assert metadata.args == [:number]
      assert metadata.min_args == 2
      assert is_binary(metadata.description)
    end

    test "returns metadata for equality operators" do
      metadata = Formula.operator_metadata("==")

      assert metadata.arity == 2
      assert metadata.args == [:any, :any]
      assert is_binary(metadata.description)
    end

    test "returns metadata for logical operators" do
      and_metadata = Formula.operator_metadata("and")
      assert and_metadata.arity == :variable
      assert and_metadata.min_args == 1

      not_metadata = Formula.operator_metadata("!")
      assert not_metadata.arity == 1
    end

    test "returns metadata for arithmetic operators" do
      plus_metadata = Formula.operator_metadata("+")
      assert plus_metadata.arity == :variable
      assert plus_metadata.args == [:number]

      div_metadata = Formula.operator_metadata("/")
      assert div_metadata.arity == 2
      assert div_metadata.args == [:number, :number]
    end

    test "returns metadata for array operators" do
      map_metadata = Formula.operator_metadata("map")
      assert map_metadata.arity == 2
      assert map_metadata.args == [:array, :formula]

      filter_metadata = Formula.operator_metadata("filter")
      assert filter_metadata.arity == 2
      assert filter_metadata.args == [:array, :formula]
    end

    test "returns default metadata for unknown operator" do
      metadata = Formula.operator_metadata("unknown_op")

      assert metadata.arity == 0
      assert metadata.args == []
      assert metadata.description == "Unknown operator"
    end

    test "all available operators have non-default metadata" do
      operators = Formula.available_operators()

      Enum.each(operators, fn op ->
        metadata = Formula.operator_metadata(op)
        assert metadata.description != "Unknown operator"
      end)
    end
  end

  describe "parse_params/1" do
    test "var with single string arg emits string form, not list" do
      params = %{"operator" => "var", "0" => %{"value" => "hp"}}
      assert Formula.parse_params(params) == %{"var" => "hp"}
    end

    test "var with two args (path + default) emits list form" do
      params = %{"operator" => "var", "0" => %{"value" => "hp"}, "1" => %{"value" => "0"}}
      assert Formula.parse_params(params) == %{"var" => ["hp", 0]}
    end

    test "nested var inside and emits string form" do
      params = %{
        "operator" => "and",
        "0" => %{"operator" => "var", "0" => %{"value" => "target.occupied"}}
      }

      assert Formula.parse_params(params) == %{"and" => [%{"var" => "target.occupied"}]}
    end
  end
end
