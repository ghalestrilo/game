defmodule Game.Combat do
  require Logger
  alias Game.{Character, Grid, TurnQueue}
  alias __MODULE__

  defstruct state: :initialized,
            players: [],
            queue: [],
            grid: %Grid{},
            current_turn: %{
              starting_position: {0, 0, 0}
            }

  @type t() :: %__MODULE__{
          state: atom(),
          players: list(any()),
          queue: list(any()),
          grid: Grid.t()
        }

  def new, do: %Combat{}

  @doc """
  This function is used to handle actions in the combat state.
  It receives the current game state and an action to perform
  The action can be an action() or a {action(), any()} tuple.
  """
  @spec act(Combat.t(), atom() | {atom(), any()}) :: {:ok, Combat.t()} | {:error, String.t()}
  def act(combat, action)

  # TODO: currently not used but in the future the :initialized state will precede the :running state
  # and represent a moment when the players are still picking their characters and decks
  def act(%Combat{state: :initialized} = combat, :add_player),
    do: {:ok, %Combat{combat | state: :running}}

  # Move:
  # - Check if it's the player's turn (pattern matching on the queue)
  # - Check if player has enough movement (in tiles)
  # - Check if the target tile is empty
  def act(
        %Combat{
          state: :running,
          queue: queue,
          grid: grid
        } = combat,
        {:move, player, target_position}
      ) do
    cond do
      not TurnQueue.is_players_turn?(queue, player) ->
        {:error, "Not player's turn"}

      Grid.distance(grid, player.position, target_position) > player.movement_range ->
        {:error, "Not enough movement"}

      Grid.tile_blocked?(grid, target_position) ->
        {:error, "Tile is blocked"}

      true ->
        # Update player position
        moved_player = Character.move(player, target_position)

        # Update grid and combat state
        updated_grid = Grid.update_position(grid, moved_player, player.position, target_position)

        updated_combat = %{
          combat
          | grid: updated_grid,
            queue: TurnQueue.rotate(queue, moved_player),
            players: update_player_in_list(combat.players, moved_player)
        }

        {:ok, updated_combat}
    end
  end

  # Play Card:
  # - Check if player has enough AP
  # - Check if target is valid
  # - Apply damage/healing
  # - Check for death
  def act(
        %Combat{state: :running, queue: queue} = combat,
        {:play_card, player, card, target_position}
      ) do
    cond do
      not TurnQueue.is_players_turn?(queue, player) ->
        {:error, "Not player's turn"}

      not Character.has_enough_ap?(player, card.cost) ->
        {:error, "Not enough AP"}

      # Get target character if any
      target = Grid.get_object(combat.grid, target_position) ->
        # Apply card effect and handle consequences
        updated_target = Character.apply_card_effect(target, card.effect)
        handle_card_effect(combat, player, updated_target)

      true ->
        {:error, "Invalid target"}
    end
  end

  # Game over check
  def act(%Combat{state: :running} = combat, {:win_check, win_or_not}) do
    case win_or_not do
      :no_win -> {:ok, combat}
      :win -> {:ok, %Combat{combat | state: :game_over}}
    end
  end

  # Catch-all for invalid actions
  def act(%Combat{} = combat, action) do
    Logger.error("""
    Invalid action-state:
    state: #{inspect(combat)}
    action: #{inspect(action)}
    """)

    {:error, "Invalid action"}
  end

  # Catch-all for invalid state
  def act(state, action) do
    Logger.error("""
    Invalid state:
    state: #{inspect(state)}
    action: #{inspect(action)}
    """)

    {:error, "Invalid state"}
  end

  # Private helper functions

  defp handle_card_effect(combat, player, target) do
    if Character.is_dead?(target) do
      # Remove dead character and check for game over
      updated_combat = remove_player(combat, target)
      check_game_over(updated_combat)
    else
      # Update target state and continue game
      updated_combat = update_player(combat, target, player)
      {:ok, updated_combat}
    end
  end

  defp remove_player(%Combat{grid: grid, players: players, queue: queue} = combat, player) do
    %{
      combat
      | grid: Grid.remove_character(grid, player),
        players: Enum.reject(players, &(&1.id == player.id)),
        queue: TurnQueue.remove_character(queue, player.id)
    }
  end

  defp update_player(
         %Combat{grid: grid, players: players, queue: queue} = combat,
         target,
         current_player
       ) do
    %{
      combat
      | grid: Grid.update_character(grid, target),
        players: update_player_in_list(players, target),
        queue:
          if target.id == current_player.id do
            TurnQueue.rotate(queue, target)
          else
            TurnQueue.update_character(TurnQueue.rotate(queue, current_player), target)
          end
    }
  end

  defp update_player_in_list(players, updated_player) do
    Enum.map(players, fn p ->
      if p.id == updated_player.id, do: updated_player, else: p
    end)
  end

  defp check_game_over(%Combat{players: players} = combat) do
    remaining_teams =
      players
      |> Enum.map(& &1.team)
      |> Enum.uniq()
      |> length()

    if remaining_teams <= 1 do
      {:ok, %Combat{combat | state: :game_over}}
    else
      {:ok, combat}
    end
  end
end
