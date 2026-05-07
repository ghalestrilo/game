defmodule Game.Combat.CardEffects.DamageTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Damage
  alias Game.{Card, Character, CombatState, Grid, Fixtures}

  describe "Damage effect" do
    setup do
      warrior = Fixtures.fighter()
      mage = %{Fixtures.mage() | hp: 15, position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat_state = %CombatState{
        state: :running,
        __constants__: %{players: [warrior, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{
          starting_position: warrior.position,
          player: warrior,
          card: nil
        }
      }

      damage_effect = %Damage{type: :damage, value: 5}

      {:ok, combat_state: combat_state, damage_effect: damage_effect, mage: mage}
    end

    test "process/3 reduces target HP by damage value", %{
      combat_state: combat_state,
      damage_effect: damage_effect,
      mage: mage
    } do
      original_hp = mage.hp
      updated_state = CardEffect.process(damage_effect, mage, combat_state)

      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp == original_hp - 5
    end

    test "get_description/1 returns correct damage description", %{damage_effect: damage_effect} do
      description = CardEffect.get_description(damage_effect)
      assert description == "Deal 5 damage to target"
    end

    test "process/3 with large damage value", %{combat_state: combat_state, mage: mage} do
      large_damage = %Damage{type: :damage, value: 20}
      updated_state = CardEffect.process(large_damage, mage, combat_state)

      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp <= 0
    end
  end

  describe "Damage effect with procedural value" do
    setup do
      warrior = %{Fixtures.fighter() | hp: 15, max_hp: 20}
      mage = %{Fixtures.mage() | hp: 12, max_hp: 20, position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat_state = %CombatState{
        state: :running,
        __constants__: %{players: [warrior, mage]},
        queue: [warrior, mage],
        grid: grid,
        current_turn: %{
          starting_position: warrior.position,
          player: warrior,
          card: nil
        }
      }

      {:ok, combat_state: combat_state, warrior: warrior, mage: mage}
    end

    defp card_with(effect_value) do
      %Card{
        id: 99,
        name: "Test",
        cost: 0,
        effects: [%{"type" => "damage", "value" => effect_value}],
        targeting: %{"type" => "character"}
      }
    end

    test "caster.hp expression deals damage equal to caster hp", %{
      combat_state: combat_state,
      warrior: warrior,
      mage: mage
    } do
      {updated_state, _} =
        Card.process_card(combat_state, mage, card_with(%{"var" => "caster.hp"}))

      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp == mage.hp - warrior.hp
    end

    test "arithmetic expression caster.max_hp - caster.hp deals missing HP as damage", %{
      combat_state: combat_state,
      warrior: warrior,
      mage: mage
    } do
      expr = %{"-" => [%{"var" => "caster.max_hp"}, %{"var" => "caster.hp"}]}
      {updated_state, _} = Card.process_card(combat_state, mage, card_with(expr))
      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp == mage.hp - (warrior.max_hp - warrior.hp)
    end

    test "target.hp expression deals damage equal to target hp", %{
      combat_state: combat_state,
      mage: mage
    } do
      {updated_state, _} =
        Card.process_card(combat_state, mage, card_with(%{"var" => "target.hp"}))

      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp == 0
    end
  end

  describe "Damage effect with shield" do
    setup do
      warrior = Fixtures.fighter()
      mage = %{Fixtures.mage() | hp: 15, position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: warrior},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat_state = %CombatState{
        state: :running,
        __constants__: %{players: [warrior, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{
          starting_position: warrior.position,
          player: warrior,
          card: nil
        }
      }

      {:ok, combat_state: combat_state, mage: mage}
    end

    test "shield absorbs all damage when shield >= damage", %{
      combat_state: combat_state,
      mage: mage
    } do
      # Add shield to mage
      mage_with_shield = Character.add_status_effect(mage, %{type: :shield, value: 10})
      original_hp = mage_with_shield.hp

      # Update combat state with shielded mage
      combat_state = %{
        combat_state
        | queue: [mage_with_shield]
      }

      # Apply 5 damage
      damage_effect = %Damage{type: :damage, value: 5}
      updated_state = CardEffect.process(damage_effect, mage_with_shield, combat_state)
      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))

      # HP should remain unchanged
      assert updated_mage.hp == original_hp

      # Shield should be reduced by damage amount
      shield = Character.get_status_effect(updated_mage, :shield)
      assert shield.value == 5
    end

    test "shield is consumed and remaining damage goes to HP", %{
      combat_state: combat_state,
      mage: mage
    } do
      # Add shield to mage
      mage_with_shield = Character.add_status_effect(mage, %{type: :shield, value: 3})
      original_hp = mage_with_shield.hp

      # Update combat state with shielded mage
      combat_state = %{
        combat_state
        | queue: [mage_with_shield]
      }

      # Apply 5 damage (3 absorbed by shield, 2 to HP)
      damage_effect = %Damage{type: :damage, value: 5}
      updated_state = CardEffect.process(damage_effect, mage_with_shield, combat_state)
      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))

      # HP should be reduced by remaining damage (5 - 3 = 2)
      assert updated_mage.hp == original_hp - 2

      # Shield should be removed
      shield = Character.get_status_effect(updated_mage, :shield)
      assert shield == nil
    end

    test "shield completely absorbs damage equal to shield value", %{
      combat_state: combat_state,
      mage: mage
    } do
      # Add shield to mage
      mage_with_shield = Character.add_status_effect(mage, %{type: :shield, value: 5})
      original_hp = mage_with_shield.hp

      # Update combat state with shielded mage
      combat_state = %{
        combat_state
        | queue: [mage_with_shield]
      }

      # Apply damage equal to shield
      damage_effect = %Damage{type: :damage, value: 5}
      updated_state = CardEffect.process(damage_effect, mage_with_shield, combat_state)
      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))

      # HP should remain unchanged
      assert updated_mage.hp == original_hp

      # Shield should be reduced to 0 but still present
      shield = Character.get_status_effect(updated_mage, :shield)
      assert shield.value == 0
    end

    test "damage applies normally when no shield present", %{
      combat_state: combat_state,
      mage: mage
    } do
      original_hp = mage.hp

      # Apply damage without shield
      damage_effect = %Damage{type: :damage, value: 5}
      updated_state = CardEffect.process(damage_effect, mage, combat_state)
      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))

      # HP should be reduced by full damage
      assert updated_mage.hp == original_hp - 5

      # No shield should be present
      shield = Character.get_status_effect(updated_mage, :shield)
      assert shield == nil
    end
  end

  describe "False Life + Exsanguinate combo" do
    # False Life: ModifyAttribute{max_hp, +4, permanent} cast on self while at full HP.
    # Exsanguinate: damage = caster.max_hp - caster.hp  (missing HP formula).
    #
    # After False Life the caster's effective max_hp is 24 but current hp remains 20,
    # so effective missing HP = 4. Exsanguinate should deal 4 damage on the first turn.

    setup do
      # Fighter at full HP (20/20). False Life grants +4 effective max_hp → 24 effective / 20 actual.
      fighter =
        %{Fixtures.fighter() | hp: 20, max_hp: 20}
        |> Character.add_status_effect(%{
          type: :modify_attribute,
          attribute: "max_hp",
          value: 4,
          duration: nil
        })

      mage = %{Fixtures.mage() | hp: 15, max_hp: 15, position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat_state = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{
          starting_position: fighter.position,
          player: fighter,
          card: nil
        }
      }

      {:ok, combat_state: combat_state, fighter: fighter, mage: mage}
    end

    test "deals damage equal to effective missing HP (4)", %{
      combat_state: combat_state,
      mage: mage
    } do
      # Exsanguinate: damage = effective_max_hp - current_hp = 24 - 20 = 4
      exsanguinate = %Card{
        id: 99,
        name: "Exsanguinate",
        cost: 0,
        effects: [%{"type" => "damage", "value" => %{"-" => [%{"var" => "caster.max_hp"}, %{"var" => "caster.hp"}]}}],
        targeting: %{"type" => "character"}
      }

      {updated_state, _} = Card.process_card(combat_state, mage, exsanguinate)
      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp == mage.hp - 4
    end

    test "deals 0 damage when caster has no False Life and is at full HP", %{
      combat_state: combat_state,
      mage: mage,
      fighter: fighter
    } do
      # Remove the False Life effect so caster is genuinely full HP with no modifier
      plain_fighter = %{fighter | status_effects: []}
      combat_state = put_in(combat_state, [:current_turn, :player], plain_fighter)

      exsanguinate = %Card{
        id: 99,
        name: "Exsanguinate",
        cost: 0,
        effects: [%{"type" => "damage", "value" => %{"-" => [%{"var" => "caster.max_hp"}, %{"var" => "caster.hp"}]}}],
        targeting: %{"type" => "character"}
      }

      {updated_state, _} = Card.process_card(combat_state, mage, exsanguinate)
      updated_mage = Enum.find(updated_state.queue, &(&1.id == mage.id))
      assert updated_mage.hp == mage.hp
    end
  end
end
