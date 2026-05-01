defmodule Game.FormulaAliasTest do
  use Game.DataCase, async: true
  alias Game.Formula
  alias Game.FormulaAliases

  describe "resolve/2 alias expansion" do
    test "resolves a formula with no aliases unchanged" do
      assert Formula.resolve(%{"+" => [1, 2]}) == 3
    end

    test "expands a string-form alias node" do
      {:ok, _} =
        FormulaAliases.create_formula_alias(%{
          name: "always_true",
          expression: %{"===" => [1, 1]}
        })

      assert Formula.resolve(%{"alias" => "always_true"}) == true
    end

    test "expands a list-form alias node (editor wire format)" do
      {:ok, _} =
        FormulaAliases.create_formula_alias(%{
          name: "always_true",
          expression: %{"===" => [1, 1]}
        })

      assert Formula.resolve(%{"alias" => ["always_true"]}) == true
    end

    test "expands alias using data context" do
      {:ok, _} =
        FormulaAliases.create_formula_alias(%{
          name: "caster_missing_hp",
          expression: %{"-" => [%{"var" => "caster.max_hp"}, %{"var" => "caster.hp"}]}
        })

      result =
        Formula.resolve(%{"alias" => "caster_missing_hp"}, %{
          "caster" => %{"max_hp" => 30, "hp" => 22}
        })

      assert result == 8
    end

    test "expands alias nested inside a larger formula" do
      {:ok, _} =
        FormulaAliases.create_formula_alias(%{
          name: "self",
          expression: %{"===" => [%{"var" => "caster.id"}, %{"var" => "target.id"}]}
        })

      formula = %{"!" => [%{"alias" => "self"}]}
      context = %{"caster" => %{"id" => 1}, "target" => %{"id" => 2}}
      assert Formula.resolve(formula, context) == true

      context_self = %{"caster" => %{"id" => 1}, "target" => %{"id" => 1}}
      assert Formula.resolve(formula, context_self) == false
    end

    test "returns empty map for unknown alias name" do
      assert Formula.resolve(%{"alias" => "nonexistent"}) == %{}
    end

    test "skips DB query when no aliases are present in formula" do
      assert Formula.resolve(%{"+" => [%{"var" => "x"}, 1]}, %{"x" => 4}) == 5
    end
  end
end
