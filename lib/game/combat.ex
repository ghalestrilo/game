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
          queue: [player | _],
          current_turn: %{
            starting_position: starting_position
          },
          grid: grid
        } = combat,
        {:move, player, target_position}
      ) do
    cond do
      Grid.distance(grid, starting_position, target_position) > player.movement_range ->
        {:error, "Not enough movement"}

      Grid.tile_blocked?(grid, target_position) ->
        {:error, "Tile is blocked"}

      true ->
        {:ok, %Combat{combat | queue: [Character.move(player, target_position) | combat.queue]}}
    end
  end

  # Play Card:
  # - Check if player has enough AP
  # - Check for game over
  def act(
        %Combat{state: :running} = combat,
        {:play_card, player, card, target_position}
      ) do
    cond do
      player.ap < card.ap_cost ->
        {:error, "Not enough AP"}

      %Character{} = Grid.get_object(target_position) ->
        {:ok, next_turn(combat)}

      true ->
        {:ok, next_turn(combat)}
    end
  end

  # Game over check
  def act(%Combat{state: :running} = combat, {:win_check, win_or_not}) do
    case win_or_not do
      :no_win -> {:ok, combat}
      :win -> {:ok, %Combat{combat | state: :game_over}}
    end
  end

  # Catch-all
  def act(state, action) do
    Logger.error("""
    Invalid action-state:
    state: #{inspect(state)}
    action: #{inspect(action)}
    """)

    :error
  end

  # Mutations
  defp next_turn(%Combat{queue: [player | queue]} = combat) do
    %{combat | queue: queue ++ [player]}
  end
end
