defmodule Game.Combat do
  require Logger
  alias Game.Character
  alias Game.Grid
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
          queue: [current_player | rest],
          current_turn: %{
            starting_position: _starting_position
          },
          grid: grid
        } = combat,
        {:move, player, target_position}
      )
      when current_player.id == player.id do
    cond do
      Grid.distance(grid, player.position, target_position) > player.movement_range ->
        {:error, "Not enough movement"}

      Grid.tile_blocked?(grid, target_position) ->
        {:error, "Tile is blocked"}

      true ->
        # Update player position
        moved_player = Character.move(player, target_position)

        # Update grid to reflect new position
        updated_grid = %{
          grid
          | tiles:
              Map.update!(grid.tiles, player.position, &%{&1 | occupied_by: nil})
              |> Map.update!(target_position, &%{&1 | occupied_by: moved_player})
        }

        # Update combat state with next turn
        updated_combat = %{
          combat
          | grid: updated_grid,
            queue: rest ++ [moved_player],
            players:
              Enum.map(combat.players, fn p ->
                if p.id == player.id, do: moved_player, else: p
              end)
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
        %Combat{state: :running, queue: [current_player | rest]} = combat,
        {:play_card, player, card, target_position}
      )
      when current_player.id == player.id do
    cond do
      player.ap < card.cost ->
        {:error, "Not enough AP"}

      # Get target character if any
      target = Grid.get_object(combat.grid, target_position) ->
        # Apply card effect (damage/healing)
        updated_target =
          case card.effect do
            {:damage, amount} -> %{target | hp: target.hp - amount}
            # No cap on healing
            {:heal, amount} -> %{target | hp: target.hp + amount}
            _ -> target
          end

        # Check if target died
        {updated_combat, target_died} =
          if updated_target.hp <= 0 do
            # Remove dead character from queue and players
            {
              %{
                combat
                | # Only keep the current player
                  queue: [player],
                  players: Enum.reject(combat.players, &(&1.id == updated_target.id))
              },
              true
            }
          else
            # Update target in queue and players
            updated_queue =
              if target.id == player.id do
                # If healing self, update in rest of queue
                rest ++ [updated_target]
              else
                # If targeting other, keep them in their position
                Enum.map(rest, fn p ->
                  if p.id == target.id, do: updated_target, else: p
                end) ++ [player]
              end

            {
              %{
                combat
                | queue: updated_queue,
                  players:
                    Enum.map(combat.players, fn p ->
                      if p.id == target.id, do: updated_target, else: p
                    end)
              },
              false
            }
          end

        # Check for game over (only one team remaining)
        remaining_teams =
          updated_combat.players
          |> Enum.map(& &1.team)
          |> Enum.uniq()
          |> length()

        cond do
          remaining_teams <= 1 ->
            {:ok, %Combat{updated_combat | state: :game_over}}

          target_died ->
            {:ok, updated_combat}

          true ->
            {:ok, updated_combat}
        end

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
end
