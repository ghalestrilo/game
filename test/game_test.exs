defmodule GameTest do
  use ExUnit.Case
  alias Game.{Card, Grid}
  alias Game.Fixtures

  setup do
    # Start a new game instance for each test
    {:ok, game_pid} = Game.start_link()
    %{game_pid: game_pid}
  end

  describe "full match simulation" do
    @tag :skip

    test "simulates a complete match with movement and combat", %{game_pid: game_pid} do
      # Create two characters with different classes and positions
      fighter = %{
        Fixtures.fighter()
        | cards: %{
            draw: [],
            hand: [
              %Card{
                id: 1,
                name: "Strike",
                cost: 1,
                effects: [%{"type" => "damage", "value" => 5}],
                range: 1
              },
              %Card{
                id: 2,
                name: "Power Strike",
                cost: 3,
                effects: [%{"type" => "damage", "value" => 10}],
                range: 1
              }
            ],
            discard: []
          }
      }

      mage = %{
        Fixtures.mage()
        | cards: %{
            draw: [],
            hand: [
              %Card{
                id: 3,
                name: "Fireball",
                cost: 2,
                effects: [%{type: "damage", value: 8}],
                range: 3
              },
              %Card{
                id: 4,
                name: "Heal",
                cost: 2,
                effects: [{:heal, 5}],
                range: 1
              }
            ],
            discard: []
          }
      }

      # Create a grid with the characters' initial positions
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: mage},
          {3, 0, -3} => %{terrain: :plain, occupied_by: nil},
          {4, 0, -4} => %{terrain: :plain, occupied_by: nil},
          {5, 0, -5} => %{terrain: :plain, occupied_by: nil}
        }
      }

      # Initialize the combat
      {:ok, combat} = Game.init_combat(game_pid, [fighter, mage], grid)
      assert combat.state == :running
      assert length(combat.queue) == 2

      # Get the initial fighter state
      fighter = Enum.find(combat.queue, &(&1.id == fighter.id))

      # fighter's turn
      # 1. Move closer to the mage
      {:ok, combat} = Game.move_character(game_pid, fighter, {1, 0, -1})
      assert combat.grid.tiles[{1, 0, -1}].occupied_by.id == fighter.id
      assert combat.grid.tiles[{0, 0, 0}].occupied_by == nil

      # Get updated fighter state after movement
      fighter = Enum.find(combat.queue, &(&1.id == fighter.id))

      # 2. Play a card
      strike_card = Enum.find(fighter.cards.hand, &(&1.id == 1))
      {:ok, combat} = Game.play_card(game_pid, fighter, strike_card, {2, 0, -2})
      updated_mage = Enum.find(combat.queue, &(&1.id == mage.id))
      # 15 - 5 damage
      assert updated_mage.hp == 10

      # Get the mage's current state
      mage = updated_mage

      # Mage's turn
      # 1. Move away from the fighter
      {:ok, combat} = Game.move_character(game_pid, mage, {3, 0, -3})
      assert combat.grid.tiles[{3, 0, -3}].occupied_by.id == mage.id
      assert combat.grid.tiles[{2, 0, -2}].occupied_by == nil

      # Get updated mage state after movement
      mage = Enum.find(combat.queue, &(&1.id == mage.id))

      # 2. Play a healing card on self
      heal_card = Enum.find(mage.cards.hand, &(&1.id == 4))
      {:ok, combat} = Game.play_card(game_pid, mage, heal_card, {3, 0, -3})
      updated_mage = Enum.find(combat.queue, &(&1.id == mage.id))
      # 10 + 5 healing
      assert updated_mage.hp == 15

      # Get the fighter's current state for their next turn
      fighter = Enum.find(combat.queue, &(&1.id == fighter.id))

      # fighter's turn again
      # 1. Move closer again
      {:ok, combat} = Game.move_character(game_pid, fighter, {2, 0, -2})
      assert combat.grid.tiles[{2, 0, -2}].occupied_by.id == fighter.id
      assert combat.grid.tiles[{1, 0, -1}].occupied_by == nil

      # Get updated fighter state after movement
      fighter = Enum.find(combat.queue, &(&1.id == fighter.id))

      # 2. Play the powerful card
      power_strike = Enum.find(fighter.cards.hand, &(&1.id == 2))
      {:ok, combat} = Game.play_card(game_pid, fighter, power_strike, {3, 0, -3})
      updated_mage = Enum.find(combat.queue, &(&1.id == mage.id))
      # 15 - 10 damage
      assert updated_mage.hp == 5

      # Get the mage's current state for their final turn
      mage = updated_mage

      # Mage's final turn
      # 1. Try to move but fail (not enough movement range)
      assert {:error, "Not enough movement"} = Game.move_character(game_pid, mage, {5, 0, -5})
      assert {:ok, _combat} = Game.move_character(game_pid, mage, {4, 0, -4})

      # 2. Play fireball
      fireball = Enum.find(mage.cards.hand, &(&1.id == 3))
      {:ok, combat} = Game.play_card(game_pid, mage, fireball, {2, 0, -2})
      updated_fighter = Enum.find(combat.queue, &(&1.id == fighter.id))
      # 20 - 8 damage
      assert updated_fighter.hp == 12

      # Final state check
      final_state = Game.get_state(game_pid)
      assert final_state.combat.state == :running
      assert length(final_state.combat.queue) == 2
      assert length(final_state.combat.queue) == 2

      # Verify character positions and health
      final_fighter = Enum.find(final_state.combat.queue, &(&1.id == fighter.id))
      final_mage = Enum.find(final_state.combat.queue, &(&1.id == mage.id))

      assert final_fighter.position == {2, 0, -2}
      assert final_fighter.hp == 12
      assert final_mage.position == {4, 0, -4}
      assert final_mage.hp == 5
    end

    test "handles invalid moves and actions", %{game_pid: game_pid} do
      # Create characters with empty hands
      fighter = %{Fixtures.fighter() | cards: %{draw: [], hand: [], discard: []}}
      mage = %{Fixtures.mage() | cards: %{draw: [], hand: [], discard: []}}

      # Create grid with a wall
      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :wall, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: mage}
        }
      }

      # Initialize combat
      {:ok, combat} = Game.init_combat(game_pid, [fighter, mage], grid)

      # Get the initial fighter state
      fighter = Enum.find(combat.queue, &(&1.id == fighter.id))
      mage = Enum.find(combat.queue, &(&1.id == mage.id))

      # Try to move through wall
      assert {:error, "Tile is blocked"} = Game.move_character(game_pid, fighter, {1, 0, -1})

      # Try to move beyond range
      assert {:error, "Not enough movement"} = Game.move_character(game_pid, fighter, {3, 0, -3})

      # Try to move to occupied tile
      assert {:error, "Tile is blocked"} = Game.move_character(game_pid, fighter, {2, 0, -2})

      # Try to play card when it's not your turn
      card = %Card{
        id: 1,
        name: "Strike",
        cost: 1,
        effects: [%{type: "damage", value: 5}],
        range: 1
      }

      assert {:error, "Not player's turn"} = Game.play_card(game_pid, mage, card, {0, 0, 0})
    end
  end
end
