defmodule Game.GameStateTest do
  use ExUnit.Case, async: true
  alias Game.{GameState, CombatState, Character, Grid}

  describe "Jason.Encoder for GameState" do
    test "encodes GameState successfully" do
      game_state = %GameState{
        current_view: :combat,
        campaign: %{
          character: %Character{
            id: 1,
            name: "Hero",
            class: :warrior,
            ap: 3,
            max_ap: 3,
            hp: 20,
            max_hp: 20,
            movement_range: 2,
            team: 1,
            dead: false,
            position: {0, 0, 0},
            status_effects: []
          },
          player: %{name: "Player1"}
        },
        combat: %CombatState{
          state: :running,
          grid: %Grid{tiles: %{}},
          queue: [],
          __constants__: %{players: []},
          current_turn: %{
            player: nil,
            starting_position: {0, 0, 0},
            card: nil
          },
          shop_cards: []
        }
      }

      assert {:ok, json} = Jason.encode(game_state)
      assert is_binary(json)
      assert String.contains?(json, "combat")
      assert String.contains?(json, "campaign")
      assert String.contains?(json, "current_view")
    end

    test "can round-trip encode and decode" do
      game_state = %GameState{
        current_view: :shop,
        campaign: %{
          character: %Character{
            id: 2,
            name: "Ranger",
            class: :ranger,
            ap: 4,
            max_ap: 4,
            hp: 15,
            max_hp: 15,
            movement_range: 3,
            team: 1,
            dead: false,
            position: {1, 0, -1},
            status_effects: []
          },
          player: %{name: "TestPlayer"}
        },
        combat: %CombatState{
          state: :game_over,
          grid: %Grid{tiles: %{}},
          queue: [],
          __constants__: %{players: []},
          current_turn: %{
            player: nil,
            starting_position: {0, 0, 0},
            card: nil
          },
          shop_cards: []
        }
      }

      assert {:ok, json} = Jason.encode(game_state)
      assert {:ok, decoded} = Jason.decode(json)

      assert decoded["current_view"] == "shop"
      assert decoded["campaign"]["player"]["name"] == "TestPlayer"
      assert decoded["campaign"]["character"]["name"] == "Ranger"
      assert decoded["combat"]["state"] == "game_over"
    end
  end
end
