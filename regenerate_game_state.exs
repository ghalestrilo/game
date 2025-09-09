# Script to regenerate the initial game state for the game
# Run this with: mix run regenerate_game_state.exs

defmodule GameStateGenerator do
  alias Game.CombatState
  alias Game.Character
  alias Game.Card
  alias Game.Grid
  alias Game.CombatState.StateSave

  def run do
    # Create a clean grid with some tiles
    grid = %Grid{
      tiles: create_tiles()
    }

    # Create some characters
    warrior = %Character{
      id: 1,
      name: "Warrior",
      class: :fighter,
      position: {0, 0, 0},
      hp: 20,
      movement_range: 2,
      ap: 3,
      team: "team1",
      cards: %{
        hand: create_warrior_cards(0..4),
        draw: create_warrior_cards(5..9),
        discard: []
      }
    }

    mage = %Character{
      id: 2,
      name: "Mage",
      class: :mage,
      position: {2, -1, -1},
      hp: 15,
      movement_range: 1,
      ap: 3,
      team: "team1",
      cards: %{
        hand: create_mage_cards(),
        draw: [],
        discard: []
      }
    }

    # Create a combat state
    combat_state = %CombatState{
      state: :running,
      grid: grid,
      queue: [warrior, mage],
      current_turn: %{
        player: warrior,
        starting_position: {0, 0, 0},
        card: nil
      }
    }

    # Encode the combat state
    encoded = StateSave.encode(combat_state)

    # Print the encoded state
    IO.puts("Encoded game state:")
    IO.puts(encoded)

    # Verify it can be decoded back
    case StateSave.decode(encoded) do
      {:ok, decoded} ->
        IO.puts("Successfully verified decode!")
        IO.inspect(decoded.state, label: "State")
        IO.puts("Queue length: #{length(decoded.queue)}")

      {:error, reason} ->
        IO.puts("Error decoding: #{reason}")
    end

    # Write to a file for reference
    File.write!("game_state.txt", encoded)
    IO.puts("Wrote encoded state to game_state.txt")

    # Generate code snippet for game_live.ex
    snippet = """
    # Initial game state as a base64-encoded string
    @initial_game_state \"\"\"
    #{encoded}
    \"\"\"
    """

    File.write!("game_live_snippet.txt", snippet)
    IO.puts("Wrote code snippet to game_live_snippet.txt")
  end

  defp create_tiles do
    # Create a simple grid of tiles in a hexagonal pattern
    radius = 5

    tiles =
      for q <- -radius..radius,
          r <- -radius..radius,
          s <- -radius..radius,
          q + r + s == 0 do
        # Add tile at coordinate {q, r, s}
        {{q, r, s}, %{type: :grass, walkable: true}}
      end

    # Add some obstacles
    tiles =
      tiles ++
        [
          {{1, 1, -2}, %{type: :rock, walkable: false}},
          {{-2, 1, 1}, %{type: :rock, walkable: false}},
          {{2, -3, 1}, %{type: :rock, walkable: false}}
        ]

    Enum.into(tiles, %{})
  end

  defp create_warrior_cards(range) do
    Enum.map(range, fn id ->
      %Card{
        id: id,
        name: "Strike",
        cost: 1,
        range: 1,
        effects: [["damage", 5]]
      }
    end)
  end

  defp create_mage_cards do
    [
      %Card{
        id: 0,
        name: "Fireball",
        cost: 1,
        effects: [["damage", 10]]
      },
      %Card{
        id: 1,
        name: "Frost",
        cost: 1,
        effects: [["damage", 8], ["slow", 1]]
      },
      %Card{
        id: 2,
        name: "Shield",
        cost: 1,
        effects: [["shield", 5]]
      },
      %Card{
        id: 3,
        name: "Teleport",
        cost: 2,
        effects: [["teleport", 3]]
      },
      %Card{
        id: 4,
        name: "Heal",
        cost: 2,
        effects: [["heal", 5]]
      }
    ]
  end
end

# Run the generator
GameStateGenerator.run()
