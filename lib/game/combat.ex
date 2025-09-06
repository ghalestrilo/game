defmodule Game.Combat do
  @moduledoc """
  This module implements resolvers that receive player or game actions and coordinats calls to
  Game.CombatState methods which transform the state accordingly.
  """
  require Logger
  alias Game.Card
  alias Game.CombatState
  alias Game.{Character, Grid, TurnQueue}

  def new, do: %CombatState{}

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
          queue: queue,
          grid: grid,
          current_turn: %{starting_position: starting_position}
        } = combat,
        {:move, player, target_position}
      ) do
    cond do
      not TurnQueue.is_players_turn?(queue, player) ->
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
          queue: [player | _] = queue,
          grid: grid,
          current_turn: %{
            player: player,
            card: card
          }
        } = combat,
        {:play_card, target_position}
      ) do
    position = Grid.get_object(grid, target_position)

    cond do
      not TurnQueue.is_players_turn?(queue, player) ->
        {:error, "Not player's turn"}

      not Character.has_enough_ap?(player, card.cost) ->
        {:error, "Not enough AP"}

      is_nil(position) ->
        {:error, "There's nothing targetable in this tile"}

      elem(position, 0) == :ok ->
        {:ok, target} = position

        cond do
          # Targeting another character
          Grid.distance(grid, player.position, target.position) > card.range ->
            {:error, "Out of range"}

          target != nil ->
            result =
              combat
              |> CombatState.apply_card_effect_to_target(target, card)
              |> CombatState.check_target_death(target)
              |> CombatState.refresh_grid()
              |> CombatState.check_game_over()

            {:ok, result}

          # Invalid target (empty tile)
          true ->
            {:error, "Invalid target"}
        end
    end
  end

  # Define a `:pick_card` action
  def process_action(%CombatState{state: :running} = combat, {:pick_card, player, card}) do
    cond do
      not TurnQueue.is_players_turn?(combat.queue, player) ->
        {:error, "Not player's turn"}

      not Enum.any?(player.cards.hand, fn c -> c.id() == card.id() end) ->
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
  def process_action(%CombatState{state: state, queue: queue} = combat, {:skip_turn, player})
      when state != :game_over do
    cond do
      not TurnQueue.is_players_turn?(queue, player) ->
        {:error, "Not player's turn"}

      true ->
        result =
          combat
          |> CombatState.set_current_player(player)
          |> CombatState.discard_player_hand()
          |> CombatState.rotate_queue()
          |> CombatState.setup_next_player_turn()

        {:ok, result}
    end
  end

  # Game over check
  def process_action(%CombatState{state: :running} = combat, {:win_check, win_or_not}) do
    case win_or_not do
      :no_win -> {:ok, combat}
      :win -> {:ok, %CombatState{combat | state: :game_over}}
    end
  end

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
end
