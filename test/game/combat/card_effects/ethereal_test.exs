defmodule Game.Combat.CardEffects.EtherealTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Ethereal
  alias Game.{Card, Character, CombatState, Grid, Fixtures}

  setup do
    fighter = Fixtures.fighter()
    mage = %{Fixtures.mage() | position: {1, 0, -1}}

    grid = %Grid{
      tiles: %{
        {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
        {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
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

    attack_card = %Card{
      id: 99,
      name: "Attack",
      cost: 1,
      range: 2,
      effects: [%{"type" => "damage", "value" => 5}],
      targeting: %{"type" => "character"}
    }

    {:ok, combat: combat, fighter: fighter, mage: mage, attack_card: attack_card}
  end

  describe "process/3" do
    test "adds ethereal status with value (like stealth)", %{combat: combat, mage: mage} do
      updated = CardEffect.process(%Ethereal{value: 2}, mage, combat)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      ethereal = Character.get_status_effect(updated_mage, :ethereal)
      assert ethereal != nil
      assert ethereal.value == 2
    end
  end

  describe "ethereal blocks targeting" do
    test "play_card_on_character returns error when target is ethereal", %{
      combat: combat,
      fighter: fighter,
      mage: mage,
      attack_card: card
    } do
      ethereal_mage = Character.add_status_effect(mage, %{type: :ethereal, value: 2})

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: ethereal_mage}
        }
      }

      combat =
        %{combat | grid: grid, queue: [ethereal_mage]}
        |> CombatState.replace_player(fighter)

      combat = %{
        combat
        | state: :card_selected,
          current_turn: %{combat.current_turn | card: card}
      }

      result = Game.Combat.process_action(combat, {:play_card_on_character, ethereal_mage})
      assert {:error, _} = result
    end

    test "play_card returns error when tile is occupied by an ethereal character", %{
      combat: combat,
      fighter: fighter,
      mage: mage,
      attack_card: card
    } do
      ethereal_mage = Character.add_status_effect(mage, %{type: :ethereal, value: 2})

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: ethereal_mage}
        }
      }

      combat = %{
        combat
        | grid: grid,
          queue: [ethereal_mage],
          state: :card_selected,
          current_turn: %{combat.current_turn | card: card}
      }

      result = Game.Combat.process_action(combat, {:play_card, {1, 0, -1}})
      assert {:error, _} = result
    end

    test "ethereal does not block self-targeting", %{combat: combat, fighter: fighter} do
      ethereal_fighter = Character.add_status_effect(fighter, %{type: :ethereal, value: 2})

      self_target_card = %Card{
        id: 98,
        name: "Self Buff",
        cost: 0,
        range: 0,
        effects: [%{"type" => "shield", "value" => 5}],
        targeting: %{"type" => "character"}
      }

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: ethereal_fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %{
        combat
        | grid: grid,
          queue: [],
          state: :card_selected,
          current_turn: %{
            combat.current_turn
            | player: ethereal_fighter,
              card: self_target_card
          }
      }

      result = Game.Combat.process_action(combat, {:play_card_on_character, ethereal_fighter})
      assert {:ok, _, _} = result
    end
  end

  describe "ethereal dispels on cast" do
    test "ethereal is removed when the ethereal character plays a card", %{
      combat: combat,
      fighter: fighter
    } do
      ethereal_fighter = Character.add_status_effect(fighter, %{type: :ethereal, value: 2})

      self_card = %Card{
        id: 97,
        name: "Cast",
        cost: 0,
        range: 0,
        effects: [%{"type" => "shield", "value" => 3}],
        targeting: %{"type" => "character"}
      }

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: ethereal_fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %{
        combat
        | grid: grid,
          queue: [],
          state: :card_selected,
          current_turn: %{
            combat.current_turn
            | player: ethereal_fighter,
              card: self_card
          }
      }

      {:ok, updated, _} =
        Game.Combat.process_action(combat, {:play_card_on_character, ethereal_fighter})

      assert Character.get_status_effect(updated.current_turn.player, :ethereal) == nil
    end
  end

  describe "ethereal countdown via setup_player_turn" do
    test "ethereal ticks down each time the ethereal player's turn is set up", %{
      combat: combat,
      fighter: fighter
    } do
      ethereal_fighter = Character.add_status_effect(fighter, %{type: :ethereal, value: 3})
      combat = %{combat | current_turn: %{combat.current_turn | player: ethereal_fighter}}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      ethereal = Character.get_status_effect(next.current_turn.player, :ethereal)
      assert ethereal.value == 2
    end

    test "ethereal is removed when counter reaches 0", %{combat: combat, fighter: fighter} do
      ethereal_fighter = Character.add_status_effect(fighter, %{type: :ethereal, value: 2})
      combat = %{combat | current_turn: %{combat.current_turn | player: ethereal_fighter}}

      next =
        combat
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert Character.get_status_effect(next.current_turn.player, :ethereal) == nil
    end
  end

  describe "protocol contracts" do
    test "get_description/1" do
      assert is_binary(CardEffect.get_description(%Ethereal{value: 2}))
    end

    test "get_icon/1 returns a string" do
      assert is_binary(CardEffect.get_icon(%Ethereal{}))
    end

    test "get_value_label/1 returns a string" do
      assert is_binary(CardEffect.get_value_label(%Ethereal{value: 2}))
    end

    test "animate/1 returns label and color" do
      assert %{label: _, color: _} = CardEffect.animate(%Ethereal{})
    end
  end
end
