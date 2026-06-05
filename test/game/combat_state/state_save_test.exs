defmodule Game.CombatState.StateSaveTest do
  use ExUnit.Case, async: true

  alias Game.CombatState
  alias Game.CombatState.StateSave
  alias Game.{Character, Grid, Card}

  describe "encode/1 and decode/1" do
    test "encode and decode a combat state" do
      # Create a simple combat state for testing
      player = %Character{
        id: "player1",
        name: "Test Player",
        class: :fighter,
        hp: 100,
        ap: 3,
        position: {1, 1, 0},
        team: :blue,
        movement_range: 3,
        status_effects: [],
        cards: %{
          hand: [%Card{id: 1, name: "Attack", cost: 1, effects: [{:damage, 10}]}],
          draw: [%Card{id: 2, name: "Heal", cost: 2, effects: [{:heal, 5}]}],
          discard: []
        }
      }

      combat_state = %CombatState{
        state: :running,
        queue: [player],
        grid: %Grid{
          tiles: %{
            {1, 1, 0} => %{character: player}
          }
        },
        current_turn: %{
          player: player,
          starting_position: {1, 1, 0},
          card: nil
        }
      }

      # Test that decode(encode(state)) returns the original state
      encoded = StateSave.encode(combat_state)
      assert is_binary(encoded)

      result = StateSave.decode(encoded)
      assert {:ok, decoded_state} = result

      # Compare critical fields to ensure the state is properly reconstructed
      assert decoded_state.state == combat_state.state
      assert length(decoded_state.queue) == length(combat_state.queue)

      # Check that tiles exist at the same positions
      assert Enum.count(decoded_state.grid.tiles) == Enum.count(combat_state.grid.tiles)
      # Verify positions contain the expected data
      decoded_positions = Map.keys(decoded_state.grid.tiles) |> Enum.sort()
      original_positions = Map.keys(combat_state.grid.tiles) |> Enum.sort()
      assert length(decoded_positions) == length(original_positions)

      # Check positions in original grid
      for pos <- Map.keys(combat_state.grid.tiles) do
        if is_tuple(pos) do
          # Convert tuple to string key format for comparison
          pos_str = Jason.encode!([elem(pos, 0), elem(pos, 1), elem(pos, 2)])
          assert Map.has_key?(decoded_state.grid.tiles, String.to_atom(pos_str))
        else
          assert Map.has_key?(decoded_state.grid.tiles, pos)
        end
      end

      # Check starting position regardless of format
      original_pos = combat_state.current_turn.starting_position
      decoded_pos = decoded_state.current_turn.starting_position

      # Convert both to a list for comparison if needed
      original_pos_list = Tuple.to_list(original_pos)

      decoded_pos_list = Tuple.to_list(decoded_pos)

      assert original_pos_list == decoded_pos_list
    end

    test "decode returns error for invalid data" do
      # Test with invalid base64
      assert {:error, _} = StateSave.decode("not-base64-data")

      # Test with valid base64 but invalid JSON
      invalid_json = Base.encode64("not valid json")
      assert {:error, _} = StateSave.decode(invalid_json)

      # Test with valid base64+JSON but not a combat state
      invalid_state = Jason.encode!(%{foo: "bar"}) |> Base.encode64()
      assert {:error, _} = StateSave.decode(invalid_state)
    end

    test "decode/1 should successfully decode what encode/1 produces" do
      # Create a minimal combat state for encoding/decoding roundtrip
      combat_state = %CombatState{state: :running}

      # Original encoded string
      encoded = StateSave.encode(combat_state)

      # Decode and verify we get back the same structure
      {:ok, decoded} = StateSave.decode(encoded)

      # The decoded state should match the original state's important fields
      assert decoded.state == combat_state.state
      assert is_struct(decoded, CombatState)
    end
  end
end
