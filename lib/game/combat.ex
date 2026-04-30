defmodule Game.Combat do
  @moduledoc """
  This module implements resolvers that receive player or game actions and coordinats calls to
  Game.CombatState methods which transform the state accordingly.

  The principle is that CombatState implemens simple, atomic, composable state mutations, while Combat coordinates these calls
  without getting too involved in the implementation details of any of the associated modules
  """
  require Logger
  alias Game.Card
  alias Game.CombatState
  alias Game.{Character, Grid}

  @default_grid_padding 3

  def new, do: %CombatState{}

  def initialize_from_char_params_list(params) do
    # Create characters from the initial state
    characters =
      params
      |> Enum.with_index()
      |> Enum.map(fn {{{q, r, s}, classname, team}, idx} ->
        classname
        |> to_string()
        |> Game.Content.get_base_class_by_class!()
        |> Game.Character.from_character_data()
        |> Game.Character.shuffle_deck()
        |> Map.put(:position, {q, r, s})
        |> Map.put(:team, team)
        |> Map.put(:id, idx)
      end)

    # Extract all positions from the initial state
    positions = Enum.map(params, fn {{q, r, s}, _class, _id} -> {q, r, s} end)

    # Log characters for debugging

    # Create a grid and update it with the characters
    # Calculate the grid radius dynamically based on the positions
    max_radius =
      positions
      |> Enum.map(&Game.Grid.normalize/1)
      |> Enum.map(fn {q, r, s} -> div(abs(q) + abs(r) + abs(s), 2) end)
      |> Enum.max()

    padded_radius = max_radius + @default_grid_padding
    grid = Game.Grid.new({padded_radius, padded_radius, padded_radius})

    # Validate positions in grid
    Enum.each(positions, fn position ->
      normalized_position = Game.Grid.normalize(position)

      unless Map.has_key?(grid.tiles, normalized_position) do
        raise "Position #{inspect(position)} is outside the grid radius"
      end
    end)

    # grid =
    #   Map.update!(grid, :tiles, fn tiles ->
    #     Enum.map(tiles, fn {position, tile} ->
    #       {position,
    #        Map.put(tile, :style, get_hex_position(elem(position, 0), elem(position, 1)))}
    #     end)
    #     |> Enum.into(%{})
    #   end)

    # Update the grid with the characters
    grid = Enum.reduce(characters, grid, &Game.Grid.update_character(&2, &1))

    # Create combat struct
    %Game.CombatState{
      state: :running,
      __constants__: %{players: characters},
      queue: characters,
      grid: grid
    }
    |> CombatState.initialize_queue()
    |> CombatState.setup_player_turn()
  end

  @doc """
  This function is used to handle actions in the combat state.
  It receives the current game state and an action to perform
  The action can be an action() or a {action(), any()} tuple.
  """
  @spec process_action(Combat.t(), atom() | {atom(), any()}) ::
          {:ok, Combat.t()} | {:error, String.t()}
  def process_action(combat, action)

  # TODO: currently not used but in the future the :initialized state will precede the :running state
  # and represent a moment when the players are still picking their characters and decks
  def process_action(%CombatState{state: :initialized} = combat, :add_player),
    do: {:ok, %CombatState{combat | state: :running}}

  # Move:
  # - Check if it's the player's turn (pattern matching on the queue)
  # - Check if player has enough movement (in tiles)
  # - Check if the target tile is empty
  # - Update current_turn with the new position
  def process_action(
        %CombatState{
          state: :running,
          queue: _queue,
          grid: grid,
          current_turn: %{starting_position: starting_position}
        } = combat,
        {:move, player, target_position}
      ) do
    cond do
      not CombatState.is_players_turn?(combat, player) ->
        {:error, "Not player's turn"}

      Grid.distance(grid, starting_position, target_position) > player.movement_range ->
        {:error, "Not enough movement"}

      Grid.tile_blocked?(grid, target_position) ->
        {:error, "Tile is blocked"}

      true ->
        # First update the player's position property
        updated_combat = CombatState.update_player_position(combat, player, target_position)
        # Then properly update the grid with old and new positions
        updated_combat = CombatState.update_grid_position(updated_combat, player, target_position)
        # Finally update the queue
        result = CombatState.update_players_and_queue(updated_combat)

        {:ok, result}
    end
  end

  # Play Card:
  def process_action(
        %CombatState{
          state: :card_selected,
          queue: _queue,
          grid: grid,
          current_turn: %{
            player: player,
            card: card
          }
        } = combat,
        {:play_card, target_position}
      ) do
    cond do
      not CombatState.is_players_turn?(combat, player) ->
        {:error, "Not player's turn"}

      not Character.has_enough_ap?(player, card.cost) ->
        {:error, "Not enough AP"}

      Grid.distance(grid, player.position, target_position) > card.range ->
        {:error, "Out of range"}

      true ->
        # Use Card module to validate the target
        case Game.Card.is_target_cell_valid?(card, target_position, combat) do
          {:ok, target} ->
            # Reset state to :running
            combat_with_running_state = %{combat | state: :running}

            # For tile targeting, target is nil (we pass the position to process_card)
            # For character targeting, target is the character struct
            target_for_processing = if is_nil(target), do: target_position, else: target

            {processed_combat, animations} =
              CombatState.process_card(combat_with_running_state, target_for_processing, card)

            result =
              processed_combat
              |> then(fn combat ->
                # Only check target death for character targeting
                if is_nil(target),
                  do: combat,
                  else: CombatState.check_target_death(combat, target)
              end)
              |> CombatState.refresh_grid()
              |> CombatState.check_game_over()

            {:ok, result, animations}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def process_action(%CombatState{state: :running} = combat, {:pick_card, player, card}) do
    cond do
      not CombatState.is_players_turn?(combat, player) ->
        {:error, "Not player's turn"}

      not Enum.any?(player.cards.hand, fn c -> c.id == card.id end) ->
        {:error, "Card not in hand"}

      true ->
        {:ok,
         %{
           combat
           | state: :card_selected,
             current_turn: %{combat.current_turn | card: card}
         }}
    end
  end

  def process_action(
        %CombatState{
          state: :card_selected,
          current_turn: %{card: card} = current_turn
        } = combat,
        {:pick_card, _player, card}
      ) do
    {:ok, %{combat | state: :running, current_turn: %{current_turn | card: nil}}}
  end

  def process_action(
        %CombatState{
          state: :card_selected,
          current_turn: %{card: %Card{}} = current_turn
        } = combat,
        {:pick_card, _player, card}
      ) do
    {:ok, %{combat | current_turn: %{current_turn | card: card}}}
  end

  # Skip Turn:
  # - Check if it's the player's turn
  # - Discard their hand
  # - Move to the next player's turn
  def process_action(%CombatState{state: state, queue: _queue} = combat, {:skip_turn, player})
      when state != :game_over do
    cond do
      not CombatState.is_players_turn?(combat, player) ->
        {:error, "Not player's turn"}

      true ->
        result =
          combat
          |> CombatState.rotate_queue()
          |> CombatState.setup_player_turn()

        # |> CombatState.setup_next_player_turn()

        {:ok, result}
    end
  end

  # # Game over check
  # def process_action(%CombatState{state: :running} = combat, {:win_check, win_or_not}) do
  #   case win_or_not do
  #     :no_win -> {:ok, combat}
  #     :win -> {:ok, %CombatState{combat | state: :game_over}}
  #   end
  # end

  # Catch-all for invalid actions
  def process_action(%CombatState{} = combat, action) do
    Logger.error("""
    Invalid action-state:
    action: #{inspect(action)}
    ------------------------------------
    state: #{inspect(combat)}
    """)

    {:error, "Invalid action"}
  end

  # lCatch-all for invalid state
  def process_action(state, action) do
    Logger.error("""
    Invalid state:
    action: #{inspect(action)}
    ------------------------------------
    state: #{inspect(state)}
    """)

    {:error, "Invalid state"}
  end

  def get_available_card_effects() do
    [
      "damage",
      "heal",
      "draw",
      "summon",
      "shield",
      "discard"
      # "stealth",
      # "stun",
      # "burn",
      # "cleanse",
      # "dodge",
      # "growth",
      # "move",
      # "poison",
      # "position",
      # "regen",
      # "root",
      # "slow",
      # "taunt"
    ]
  end
end
