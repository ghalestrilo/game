defmodule Game.Combat.CardEffects.ModifyAttributeTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.ModifyAttribute
  alias Game.{Character, CombatState, Grid, Fixtures}

  setup do
    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {1, 0, -1}}

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage},
        {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
      }
    }

    combat = %CombatState{
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

    {:ok, combat: combat, fighter: fighter, mage: mage}
  end

  describe "process/3" do
    test "adds modify_attribute status effect to target", %{combat: combat, mage: mage} do
      effect = %ModifyAttribute{attribute: "max_hp", value: 10, duration: 3}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      se = Character.get_status_effect(updated_mage, :modify_attribute)
      assert se != nil
      assert se.attribute == "max_hp"
      assert se.value == 10
      assert se.duration == 3
    end

    test "permanent effect has duration nil", %{combat: combat, mage: mage} do
      effect = %ModifyAttribute{attribute: "max_ap", value: -1, duration: nil}
      updated = CardEffect.process(effect, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      se = Character.get_status_effect(updated_mage, :modify_attribute)
      assert se.duration == nil
    end
  end

  describe "effective_attribute/2" do
    test "returns base value when no modifiers present", %{fighter: fighter} do
      assert Character.effective_attribute(fighter, "max_hp") == fighter.max_hp
    end

    test "stacks additive modifiers" do
      fighter = %Character{
        id: 1,
        max_hp: 20,
        max_ap: 3,
        movement_range: 2,
        hand_size: 5,
        damage_multiplier: 1.0,
        hp: 20,
        ap: 3,
        position: {0, 0, 0},
        team: :team1,
        cards: %{draw: [], hand: [], discard: []},
        status_effects: [
          %{type: :modify_attribute, attribute: "max_hp", value: 5, duration: 2},
          %{type: :modify_attribute, attribute: "max_hp", value: 3, duration: nil}
        ]
      }

      assert Character.effective_attribute(fighter, "max_hp") == 28
    end

    test "only applies modifiers matching the requested attribute" do
      fighter = %Character{
        id: 1,
        max_hp: 20,
        max_ap: 3,
        movement_range: 2,
        hand_size: 5,
        damage_multiplier: 1.0,
        hp: 20,
        ap: 3,
        position: {0, 0, 0},
        team: :team1,
        cards: %{draw: [], hand: [], discard: []},
        status_effects: [
          %{type: :modify_attribute, attribute: "max_ap", value: 2, duration: 1}
        ]
      }

      assert Character.effective_attribute(fighter, "max_hp") == 20
      assert Character.effective_attribute(fighter, "max_ap") == 5
    end
  end

  describe "movement_range integration" do
    test "character with movement_range modifier cannot move beyond reduced range", %{
      combat: combat,
      fighter: fighter
    } do
      debuffed =
        Character.add_status_effect(fighter, %{
          type: :modify_attribute,
          attribute: "movement_range",
          value: -1,
          duration: 2
        })

      combat = %{combat | current_turn: %{combat.current_turn | player: debuffed}}
      # fighter movement_range: 2, modifier: -1 → effective 1; tile at distance 2 should fail
      result = Game.Combat.process_action(combat, {:move, debuffed, {2, 0, -2}})
      assert result == {:error, "Not enough movement"}
    end

    test "character with movement_range buff can reach further tiles", %{
      combat: combat,
      fighter: fighter
    } do
      buffed =
        Character.add_status_effect(fighter, %{
          type: :modify_attribute,
          attribute: "movement_range",
          value: 1,
          duration: 2
        })

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: buffed},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil},
          {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %{
        combat
        | grid: grid,
          queue: [],
          current_turn: %{combat.current_turn | player: buffed}
      }

      # fighter movement_range: 2, modifier: +1 → effective 3; distance-3 tile should succeed
      assert {:ok, _} = Game.Combat.process_action(combat, {:move, buffed, {3, 0, -3}})
    end
  end

  describe "hand_size integration" do
    test "character with hand_size modifier draws more cards at turn start", %{
      combat: combat,
      fighter: fighter
    } do
      buffed =
        Character.add_status_effect(fighter, %{
          type: :modify_attribute,
          attribute: "hand_size",
          value: 2,
          duration: nil
        })

      # fighter is current player; rotate so mage goes first, then fighter gets setup_player_turn
      combat = %{combat | current_turn: %{combat.current_turn | player: buffed}, queue: [buffed]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == fighter.id
      assert length(next.current_turn.player.cards.hand) == 7
    end
  end

  describe "max_hp integration" do
    test "regen is capped at effective max_hp when buffed", %{combat: combat, fighter: fighter} do
      fighter = %{fighter | max_hp: 20}

      buffed =
        Character.add_status_effect(fighter, %{
          type: :modify_attribute,
          attribute: "max_hp",
          value: 10,
          duration: nil
        })

      # Also give regen to tick during setup_player_turn
      buffed = Character.add_status_effect(buffed, %{type: :regen, heal: 100, value: 2})
      buffed = %{buffed | hp: 1}
      combat = %{combat | current_turn: %{combat.current_turn | player: buffed}, queue: [buffed]}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == fighter.id
      # HP should be capped at effective max_hp = 20 + 10 = 30, not beyond
      assert next.current_turn.player.hp <= 30
      assert next.current_turn.player.hp > fighter.max_hp
    end
  end

  describe "duration countdown via setup_player_turn" do
    test "timed modifier decrements duration each turn", %{combat: combat, fighter: fighter} do
      modified =
        Character.add_status_effect(fighter, %{
          type: :modify_attribute,
          attribute: "max_hp",
          value: 5,
          duration: 2
        })

      combat = %{combat | current_turn: %{combat.current_turn | player: modified}}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      se = Character.get_status_effect(next.current_turn.player, :modify_attribute)
      assert se.duration == 1
    end

    test "timed modifier is removed when duration reaches 0", %{combat: combat, fighter: fighter} do
      modified =
        Character.add_status_effect(fighter, %{
          type: :modify_attribute,
          attribute: "max_hp",
          value: 5,
          duration: 1
        })

      combat = %{combat | current_turn: %{combat.current_turn | player: modified}}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert Character.get_status_effect(next.current_turn.player, :modify_attribute) == nil
    end

    test "permanent modifier (duration: nil) is never removed by tick", %{
      combat: combat,
      fighter: fighter
    } do
      modified =
        Character.add_status_effect(fighter, %{
          type: :modify_attribute,
          attribute: "max_hp",
          value: 5,
          duration: nil
        })

      combat = %{combat | current_turn: %{combat.current_turn | player: modified}}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert next.current_turn.player.id == fighter.id
      se = Character.get_status_effect(next.current_turn.player, :modify_attribute)
      assert se != nil
      assert se.duration == nil
    end
  end

  describe "protocol contracts" do
    test "get_description/1 with duration" do
      assert is_binary(
               CardEffect.get_description(%ModifyAttribute{
                 attribute: "max_hp",
                 value: 5,
                 duration: 2
               })
             )
    end

    test "get_description/1 permanent" do
      assert is_binary(
               CardEffect.get_description(%ModifyAttribute{
                 attribute: "max_ap",
                 value: -1,
                 duration: nil
               })
             )
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%ModifyAttribute{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%ModifyAttribute{value: 5}))
    end

    test "animate/1 returns label and color for buff" do
      assert %{label: _, color: :green} = CardEffect.animate(%ModifyAttribute{value: 5})
    end

    test "animate/1 returns label and color for debuff" do
      assert %{label: _, color: :yellow} = CardEffect.animate(%ModifyAttribute{value: -1})
    end

    test "params/1 includes attribute, value, duration" do
      params = CardEffect.params(%ModifyAttribute{})
      assert "attribute" in params
      assert "value" in params
      assert "duration" in params
    end
  end
end
