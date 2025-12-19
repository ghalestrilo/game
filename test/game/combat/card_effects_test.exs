defmodule Game.Combat.CardEffectsTest do
  use ExUnit.Case, async: true

  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects.{Damage, Heal, Draw, Discard, Summon}
  alias Game.{CombatState, Grid, Fixtures}

  describe "Damage effect" do
    setup do
      warrior = Fixtures.warrior()
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

  describe "Heal effect" do
    setup do
      warrior = %{Fixtures.warrior() | hp: 10}
      mage = Fixtures.mage()

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

      heal_effect = %Heal{type: :heal, value: 5}

      {:ok, combat_state: combat_state, heal_effect: heal_effect, warrior: warrior}
    end

    test "process/3 increases target HP by heal value", %{
      combat_state: combat_state,
      heal_effect: heal_effect,
      warrior: warrior
    } do
      original_hp = warrior.hp
      updated_state = CardEffect.process(heal_effect, warrior, combat_state)

      updated_warrior = updated_state.current_turn.player
      assert updated_warrior.hp == original_hp + 5
    end

    test "get_description/1 returns correct heal description", %{heal_effect: heal_effect} do
      description = CardEffect.get_description(heal_effect)
      assert description == "Restores 5 hp to target"
    end

    test "process/3 with large heal value", %{combat_state: combat_state, warrior: warrior} do
      large_heal = %Heal{type: :heal, value: 100}
      updated_state = CardEffect.process(large_heal, warrior, combat_state)

      updated_warrior = updated_state.current_turn.player
      # Should cap at max HP
      assert updated_warrior.hp >= warrior.hp
    end
  end

  describe "Draw effect" do
    setup do
      warrior = %{
        Fixtures.warrior()
        | cards: %{
            draw: [
              %{Fixtures.attack_card() | id: 1},
              %{Fixtures.attack_card() | id: 2},
              %{Fixtures.attack_card() | id: 3}
            ],
            hand: [],
            discard: []
          }
      }

      mage = Fixtures.mage()

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

      draw_effect = %Draw{type: :draw, value: 2}

      {:ok, combat_state: combat_state, draw_effect: draw_effect, warrior: warrior}
    end

    test "process/3 draws specified number of cards into hand", %{
      combat_state: combat_state,
      draw_effect: draw_effect,
      warrior: warrior
    } do
      original_hand_size = length(warrior.cards.hand)
      original_draw_pile_size = length(warrior.cards.draw)

      updated_state = CardEffect.process(draw_effect, warrior, combat_state)
      updated_warrior = updated_state.current_turn.player

      assert length(updated_warrior.cards.hand) == original_hand_size + 2
      assert length(updated_warrior.cards.draw) == original_draw_pile_size - 2
    end

    test "get_description/1 returns correct draw description for single card" do
      draw_one = %Draw{type: :draw, value: 1}
      description = CardEffect.get_description(draw_one)
      assert description == "Draw 1 card"
    end

    test "get_description/1 returns correct draw description for multiple cards", %{
      draw_effect: draw_effect
    } do
      description = CardEffect.get_description(draw_effect)
      assert description == "Draw 2 cards"
    end

    test "process/3 when draw pile is empty", %{combat_state: combat_state} do
      warrior_empty_draw = %{
        Fixtures.warrior()
        | cards: %{
            draw: [],
            hand: [],
            discard: [
              %{Fixtures.attack_card() | id: 1},
              %{Fixtures.attack_card() | id: 2}
            ]
          }
      }

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: warrior_empty_draw}
      }

      draw_effect = %Draw{type: :draw, value: 2}
      updated_state = CardEffect.process(draw_effect, warrior_empty_draw, combat_state)
      updated_warrior = updated_state.current_turn.player

      # Should reshuffle discard pile into draw pile and then draw
      assert length(updated_warrior.cards.hand) > 0
    end
  end

  describe "Discard effect" do
    setup do
      warrior = %{
        Fixtures.warrior()
        | cards: %{
            draw: [],
            hand: [
              %{Fixtures.attack_card() | id: 1},
              %{Fixtures.attack_card() | id: 2},
              %{Fixtures.attack_card() | id: 3}
            ],
            discard: []
          }
      }

      mage = Fixtures.mage()

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

      discard_effect = %Discard{type: :discard, value: 2}

      {:ok, combat_state: combat_state, discard_effect: discard_effect, warrior: warrior}
    end

    test "process/3 discards specified number of cards from hand", %{
      combat_state: combat_state,
      discard_effect: discard_effect,
      warrior: warrior
    } do
      original_hand_size = length(warrior.cards.hand)
      original_discard_size = length(warrior.cards.discard)

      updated_state = CardEffect.process(discard_effect, warrior, combat_state)
      updated_warrior = updated_state.current_turn.player

      assert length(updated_warrior.cards.hand) == original_hand_size - 2
      assert length(updated_warrior.cards.discard) == original_discard_size + 2
    end

    test "get_description/1 returns correct discard description for single card" do
      discard_one = %Discard{type: :discard, value: 1}
      description = CardEffect.get_description(discard_one)
      assert description == "Discard 1 card from target's hand"
    end

    test "get_description/1 returns correct discard description for multiple cards", %{
      discard_effect: discard_effect
    } do
      description = CardEffect.get_description(discard_effect)
      assert description == "Discard 2 cards from target's hand"
    end

    test "process/3 when hand has fewer cards than discard value", %{
      combat_state: combat_state
    } do
      warrior_small_hand = %{
        Fixtures.warrior()
        | cards: %{
            draw: [],
            hand: [%{Fixtures.attack_card() | id: 1}],
            discard: []
          }
      }

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: warrior_small_hand}
      }

      discard_effect = %Discard{type: :discard, value: 5}
      updated_state = CardEffect.process(discard_effect, warrior_small_hand, combat_state)
      updated_warrior = updated_state.current_turn.player

      # Should only discard what's available
      assert length(updated_warrior.cards.hand) == 0
      assert length(updated_warrior.cards.discard) == 1
    end

    test "process/3 when hand is empty", %{combat_state: combat_state} do
      warrior_empty_hand = %{
        Fixtures.warrior()
        | cards: %{
            draw: [],
            hand: [],
            discard: []
          }
      }

      combat_state = %{
        combat_state
        | current_turn: %{combat_state.current_turn | player: warrior_empty_hand}
      }

      discard_effect = %Discard{type: :discard, value: 2}
      updated_state = CardEffect.process(discard_effect, warrior_empty_hand, combat_state)
      updated_warrior = updated_state.current_turn.player

      # Should handle gracefully
      assert length(updated_warrior.cards.hand) == 0
      assert length(updated_warrior.cards.discard) == 0
    end
  end

  describe "Summon effect" do
    setup do
      warrior = Fixtures.warrior()
      mage = Fixtures.mage()

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

      summon_character = %{Fixtures.warrior() | id: 3, name: "Summoned Warrior"}
      summon_effect = %Summon{type: :summon, character: summon_character}

      {:ok, combat_state: combat_state, summon_effect: summon_effect}
    end

    test "process/3 currently returns unchanged combat state (WIP)", %{
      combat_state: combat_state,
      summon_effect: summon_effect
    } do
      target = Fixtures.warrior()
      updated_state = CardEffect.process(summon_effect, target, combat_state)

      # Currently WIP, should return unchanged state
      assert updated_state == combat_state
    end

    test "get_description/1 returns WIP summon description", %{summon_effect: summon_effect} do
      description = CardEffect.get_description(summon_effect)
      assert description == "[WIP] Summons a Summoned Warrior at seleted tile"
    end
  end
end
