defmodule Game.Combat.CardEffects.StealthTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.Stealth
  alias Game.{Card, Character, CombatState, Grid, Fixtures}

  setup do
    fighter = Fixtures.fighter()
    mage = Fixtures.mage()

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

    hide_card = %Card{
      id: 9999,
      name: "Hide",
      cost: 0,
      effects: [%Stealth{value: 1}],
      targeting: %{"type" => "character"}
    }

    {:ok, combat: combat, fighter: fighter, mage: mage, hide_card: hide_card}
  end

  describe "Stealth effect" do
    test "process/3 adds stealth status with duration + 1", %{combat: combat, fighter: fighter} do
      updated = CardEffect.process(%Stealth{value: 1}, fighter, combat)
      stealth = Character.get_status_effect(updated.current_turn.player, :stealth)
      assert stealth != nil
      assert stealth.value == 2
    end

    test "get_description/1 returns correct description" do
      assert CardEffect.get_description(%Stealth{value: 1}) == "Become hidden for 2 turns"
    end

    test "animate/1 returns HIDDEN label in yellow" do
      assert CardEffect.animate(%Stealth{}) == %{label: "HIDDEN", color: :yellow}
    end
  end

  describe "stealth duration countdown via setup_player_turn" do
    test "stealth ticks down by 1 each time the hidden player's turn is set up", %{
      combat: combat,
      fighter: fighter,
      hide_card: hide_card
    } do
      # Fighter self-casts Hide (value: 1 → stored as 2)
      {combat_after_hide, _anims} = Card.process_card(combat, fighter, hide_card)
      hidden_fighter = combat_after_hide.current_turn.player
      assert Character.get_status_effect(hidden_fighter, :stealth).value == 2

      # Rotate to mage's turn (fighter goes to queue)
      combat_mage_turn = CombatState.rotate_queue(combat_after_hide)
      combat_mage_setup = CombatState.setup_player_turn(combat_mage_turn)

      # Fighter is now in the queue — stealth unchanged (tick only fires on the hidden player's turn)
      fighter_in_queue = Enum.find(combat_mage_setup.queue, &(&1.id == fighter.id))
      assert Character.get_status_effect(fighter_in_queue, :stealth).value == 2

      # Rotate back to fighter's turn — setup_player_turn ticks stealth: 2 → 1
      combat_fighter_turn2 = CombatState.rotate_queue(combat_mage_setup)
      combat_fighter_setup2 = CombatState.setup_player_turn(combat_fighter_turn2)

      assert Character.get_status_effect(combat_fighter_setup2.current_turn.player, :stealth).value == 1
    end

    test "stealth expires (is removed) when the counter reaches 0", %{
      combat: combat,
      fighter: fighter,
      hide_card: hide_card
    } do
      {combat_after_hide, _} = Card.process_card(combat, fighter, hide_card)

      # stealth stored as 2 (value 1 + 1 for current turn).
      # Tick fires each time fighter's turn is set up.
      # Rotation 1 (mage turn): no tick for fighter. fighter queue: stealth=2
      # Rotation 2 (fighter turn): tick 2→1
      # Rotation 3 (mage turn): no tick for fighter. fighter queue: stealth=1
      # Rotation 4 (fighter turn): tick 1→0, removed
      combat_expired =
        combat_after_hide
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()
        |> CombatState.rotate_queue()
        |> CombatState.setup_player_turn()

      assert Character.get_status_effect(combat_expired.current_turn.player, :stealth) == nil
    end
  end

  describe "visible_to? logic (board visibility)" do
    test "stealthy character is not visible to an enemy player" do
      stealthy = %{team: :a, status_effects: [%{type: :stealth, value: 1}]}
      observer = %{team: :b}
      refute GameWeb.CombatLive.visible_to_for_test?(stealthy, observer)
    end

    test "stealthy character is visible to a teammate" do
      stealthy = %{team: :a, status_effects: [%{type: :stealth, value: 1}]}
      teammate = %{team: :a}
      assert GameWeb.CombatLive.visible_to_for_test?(stealthy, teammate)
    end

    test "non-stealthy character is visible to everyone" do
      plain = %{team: :a, status_effects: []}
      enemy = %{team: :b}
      assert GameWeb.CombatLive.visible_to_for_test?(plain, enemy)
    end

    test "any character is visible when current_player is nil (campaign/single-player)" do
      stealthy = %{team: :a, status_effects: [%{type: :stealth, value: 1}]}
      assert GameWeb.CombatLive.visible_to_for_test?(stealthy, nil)
    end
  end
end
