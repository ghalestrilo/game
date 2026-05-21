defmodule Game.Combat.CardEffects.ReviveTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Revive
  alias Game.{Card, CombatState, Grid, Fixtures}

  # Setup: mage (alive, current turn caster) + fighter (dead, in queue with dead: true)
  setup do
    dead_fighter = %{Fixtures.fighter() | dead: true, hp: 0}
    mage = %{Fixtures.mage() | position: {1, 0, -1}}

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: dead_fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
      }
    }

    combat = %CombatState{
      state: :running,
      __constants__: %{players: [dead_fighter, mage]},
      queue: [dead_fighter],
      grid: grid,
      current_turn: %{
        starting_position: mage.position,
        player: mage,
        card: nil
      }
    }

    {:ok, combat: combat, dead_fighter: dead_fighter, mage: mage}
  end

  describe "process/3 — dead target" do
    test "revives dead target with specified HP", %{combat: combat, dead_fighter: fighter} do
      updated = CardEffect.process(%Revive{value: 5}, fighter, combat)
      revived = Enum.find(CombatState.get_current_queue(updated), &(&1.id == fighter.id))
      assert revived != nil
      assert revived.hp == 5
    end

    test "revived character has dead: false", %{combat: combat, dead_fighter: fighter} do
      updated = CardEffect.process(%Revive{value: 5}, fighter, combat)
      revived = Enum.find(CombatState.get_current_queue(updated), &(&1.id == fighter.id))
      assert revived.dead == false
    end

    test "value 0 clamps hp to minimum 1", %{combat: combat, dead_fighter: fighter} do
      updated = CardEffect.process(%Revive{value: 0}, fighter, combat)
      revived = Enum.find(CombatState.get_current_queue(updated), &(&1.id == fighter.id))
      assert revived.hp == 1
    end

    test "revived character is no longer in dead_characters", %{combat: combat, dead_fighter: fighter} do
      updated = CardEffect.process(%Revive{value: 5}, fighter, combat)
      assert Enum.empty?(CombatState.dead_characters(updated))
    end
  end

  describe "process/3 — alive target (no-op guard)" do
    test "does not modify combat state when target is alive", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Revive{value: 5}, mage, combat)
      assert updated == combat
    end
  end

  describe "revived character can take a turn" do
    test "after revive, character can become current player", %{
      combat: combat,
      dead_fighter: fighter
    } do
      updated =
        combat
        |> then(&CardEffect.process(%Revive{value: 5}, fighter, &1))
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert updated.current_turn.player.id == fighter.id
    end
  end

  describe "check_game_over stays :running after revive" do
    test "game remains running when two teams are alive after revive", %{
      combat: combat,
      dead_fighter: fighter
    } do
      updated =
        combat
        |> then(&CardEffect.process(%Revive{value: 5}, fighter, &1))
        |> CombatState.check_game_over()

      assert updated.state == :running
    end
  end

  describe "targeting validation" do
    setup %{dead_fighter: fighter, mage: mage, combat: combat} do
      revive_card = %Card{
        id: 99,
        name: "Revive",
        cost: 1,
        range: 5,
        effects: [%{"type" => "revive", "value" => 5}],
        targeting: %{"type" => "character"}
      }

      non_revive_card = %Card{
        id: 98,
        name: "Strike",
        cost: 1,
        range: 1,
        effects: [%{"type" => "damage", "value" => 5}],
        targeting: %{"type" => "character"}
      }

      ressurrect_card = %Card{
        id: 341,
        name: "Ressurrect",
        cost: 3,
        range: 4,
        effects: [%{"type" => "revive", "value" => 5}, %{"type" => "self_destruct"}],
        targeting: %{"rule" => %{}, "trajectory_type" => "null", "type" => "character"}
      }

      {:ok,
       revive_card: revive_card,
       non_revive_card: non_revive_card,
       ressurrect_card: ressurrect_card,
       dead_fighter: fighter,
       mage: mage,
       combat: combat}
    end

    test "dead target is allowed for a card with revive effect", %{
      revive_card: card,
      dead_fighter: fighter,
      combat: combat
    } do
      assert {:ok, _} = Card.is_target_valid_for_character?(card, fighter, combat)
    end

    test "alive target is rejected for a card with revive effect", %{
      revive_card: card,
      mage: mage,
      combat: combat
    } do
      assert {:error, _} = Card.is_target_valid_for_character?(card, mage, combat)
    end

    test "dead target is rejected for a non-revive card", %{
      non_revive_card: card,
      dead_fighter: fighter,
      combat: combat
    } do
      assert {:error, "Cannot target a dead character"} =
               Card.is_target_valid_for_character?(card, fighter, combat)
    end

    test "Ressurrect card (live DB config) allows dead target", %{
      ressurrect_card: card,
      dead_fighter: fighter,
      combat: combat
    } do
      assert {:ok, _} = Card.is_target_valid_for_character?(card, fighter, combat)
    end

    test "Ressurrect card (live DB config) rejects alive target", %{
      ressurrect_card: card,
      mage: mage,
      combat: combat
    } do
      assert {:error, _} = Card.is_target_valid_for_character?(card, mage, combat)
    end
  end

  describe "protocol contracts" do
    test "get_description/1 returns a string" do
      assert is_binary(CardEffect.get_description(%Revive{value: 5}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Revive{}))
    end

    test "get_value_label/1 with integer value returns string" do
      assert is_binary(CardEffect.get_value_label(%Revive{value: 5}))
    end

    test "get_value_label/1 with explicit label returns that label" do
      assert CardEffect.get_value_label(%Revive{value: 5, value_label: "custom"}) == "custom"
    end

    test "animate/1 returns label and green color" do
      assert %{label: _, color: :green} = CardEffect.animate(%Revive{value: 5})
    end

    test "params/1 returns [\"value\"]" do
      assert CardEffect.params(%Revive{}) == ["value"]
    end
  end
end
