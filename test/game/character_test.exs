defmodule Game.CharacterTest do
  use ExUnit.Case, async: true
  alias Game.{Character, Fixtures}

  describe "HP is always an integer" do
    setup do
      {:ok, char: Fixtures.fighter()}
    end

    test "apply_damage with float amount gives integer hp", %{char: char} do
      result = Character.apply_damage(char, 11.0)
      assert is_integer(result.hp)
      assert result.hp == 9
    end

    test "apply_damage with fractional float rounds hp", %{char: char} do
      result = Character.apply_damage(char, 3.7)
      assert is_integer(result.hp)
      assert result.hp == 16
    end

    test "apply_damage negative branch (healing path) with float gives integer hp", %{char: char} do
      char = %{char | hp: 10}
      result = Character.apply_damage(char, -3.0)
      assert is_integer(result.hp)
      assert result.hp == 13
    end

    test "apply_healing with float amount gives integer hp", %{char: char} do
      char = %{char | hp: 10}
      result = Character.apply_healing(char, 3.0)
      assert is_integer(result.hp)
      assert result.hp == 13
    end

    test "is_dead? detects death when hp reaches 0 via float arithmetic", %{char: char} do
      # float HP from e.g. outgoing_damage_multiplier * damage leaking through
      char_float_hp = %{char | hp: 0.0}
      # Without the fix, is_dead? returns false for float HP due to the integer guard
      assert Character.is_dead?(char_float_hp)
    end
  end
end
