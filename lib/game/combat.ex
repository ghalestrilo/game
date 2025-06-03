defmodule Game.Combat do
  require Logger
  alias Game.Card
  alias Game.{Character, Grid, TurnQueue}
  alias __MODULE__

  defstruct state: :initialized,
            players: [],
            queue: [],
            grid: %Grid{},
            current_turn: %{
              player: %Character{},
              starting_position: {0, 0, 0},
              card: %Card{},
              hand: []
            }

  @type t() :: %__MODULE__{
          state: atom(),
          players: list(any()),
          queue: list(any()),
          grid: Grid.t(),
          current_turn: %{
            player: Character.t() | nil,
            starting_position: {0, 0, 0},
            card: Card.t() | nil,
            hand: list(Card.t())
          }
        }

  def new, do: %Combat{}

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
  def process_action(%Combat{state: :initialized} = combat, :add_player),
    do: {:ok, %Combat{combat | state: :running}}

  # Move:
  # - Check if it's the player's turn (pattern matching on the queue)
  # - Check if player has enough movement (in tiles)
  # - Check if the target tile is empty
  # - Update current_turn with the new position
  def process_action(
        %Combat{
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
        # Update player position
        moved_player = Character.move(player, target_position)

        # Update grid and combat state
        updated_grid = Grid.update_position(grid, moved_player, player.position, target_position)

        updated_players =
          Enum.map(combat.players, fn p -> if p.id == player.id, do: moved_player, else: p end)

        updated_queue =
          Enum.map(queue, fn p -> if p.id == player.id, do: moved_player, else: p end)

        # Update current_turn with the new position
        updated_combat = %{
          combat
          | grid: updated_grid,
            players: updated_players,
            queue: updated_queue,
            current_turn: %{combat.current_turn | starting_position: target_position}
        }

        {:ok, updated_combat}
    end
  end

  # Play Card:
  # - Check if it's the player's turn
  # - Check if player has enough AP
  # - Check if target is valid
  # - Apply damage/healing
  # - Check for death
  def process_action(
        %Combat{
          state: :card_selected,
          queue: queue,
          grid: grid,
          current_turn: %{
            player: player,
            card: card
          }
        } = combat,
        {:play_card, target_position}
      ) do
    # dbg(target_position)
    # dbg(Grid.get_object(grid, target_position))
    # dbg(grid)

    cond do
      not TurnQueue.is_players_turn?(queue, player) ->
        {:error, "Not player's turn"}

      not Character.has_enough_ap?(player, card.cost) ->
        {:error, "Not enough AP"}

      {:ok, target} = Grid.get_object(grid, target_position) ->
        # Handle self-targeting or targeting empty tiles

        cond do
          # Self-targeting (healing or damage)
          target == nil and player.position == target_position ->
            updated_player = Character.apply_card_effect(player, card.effect)
            # Update the player's state in the queue and players list
            updated_queue = TurnQueue.rotate(queue, updated_player)
            updated_players = update_player_in_list(combat.players, updated_player)
            [next_player | _] = updated_queue

            updated_combat = %{
              combat
              | queue: updated_queue,
                players: updated_players,
                state: :running,
                current_turn: %{
                  starting_position: next_player.position,
                  player: next_player,
                  card: nil,
                  hand: Enum.take(next_player.deck, 5)
                }
            }

            updated_combat = %{
              updated_combat
              | grid: Grid.update_character(updated_combat.grid, updated_player)
            }

            # Check for death after self-targeting
            if Character.is_dead?(updated_player) do
              updated_combat = remove_player(updated_combat, updated_player)
              check_game_over(updated_combat)
            else
              {:ok, updated_combat}
            end

          # Targeting another character
          target != nil ->
            updated_target = Character.apply_card_effect(target, card.effect)

            # Check for death
            if Character.is_dead?(updated_target) do
              updated_combat = remove_player(combat, updated_target)
              check_game_over(updated_combat)
            else
              # Update combat state with the target's new state
              updated_combat = %{
                combat
                | grid: Grid.update_character(combat.grid, updated_target)
              }

              updated_combat = %{
                updated_combat
                | players: update_player_in_list(combat.players, updated_target)
              }

              # Update queue - rotate after current player's action
              updated_queue = TurnQueue.rotate(queue, player)
              [next_player | _] = updated_queue

              updated_combat = %{
                updated_combat
                | queue: updated_queue,
                  state: :running,
                  current_turn: %{
                    starting_position: next_player.position,
                    player: next_player,
                    card: nil,
                    hand: Enum.take(next_player.deck, 5)
                  }
              }

              {:ok, updated_combat}
            end

          # Invalid target (empty tile)
          true ->
            {:error, "Invalid target"}
        end
    end
  end

  # Define a `:pick_card` action
  def process_action(%Combat{state: :running} = combat, {:pick_card, player, card}) do
    dbg("Processing event: pick_card")

    cond do
      not TurnQueue.is_players_turn?(combat.queue, player) ->
        {:error, "Not player's turn"}

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
        %Combat{
          state: :card_selected,
          current_turn: %{card: card} = current_turn
        } = combat,
        {:pick_card, _player, card}
      ) do
    Logger.info("Picked same card, unpicking")
    {:ok, %{combat | state: :running, current_turn: %{current_turn | card: nil}}}
  end

  def process_action(
        %Combat{
          state: :card_selected,
          current_turn: %{card: %Card{}} = current_turn
        } = combat,
        {:pick_card, _player, card}
      ) do
    Logger.info("Picked different card, updating")
    {:ok, %{combat | current_turn: %{current_turn | card: card}}}
  end

  # Game over check
  def process_action(%Combat{state: :running} = combat, {:win_check, win_or_not}) do
    case win_or_not do
      :no_win -> {:ok, combat}
      :win -> {:ok, %Combat{combat | state: :game_over}}
    end
  end

  # Catch-all for invalid actions
  def process_action(%Combat{} = combat, action) do
    Logger.error("""
    Invalid action-state:
    state: #{inspect(combat)}
    action: #{inspect(action)}
    """)

    {:error, "Invalid action"}
  end

  # lCatch-all for invalid state
  def process_action(state, action) do
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
    # Update the grid with the target's new state
    updated_grid = Grid.update_character(grid, target)

    # Update the players list with both target and current player
    updated_players = update_player_in_list(players, target)
    updated_players = update_player_in_list(updated_players, current_player)

    # Update the queue - rotate after current player's action
    updated_queue = TurnQueue.rotate(queue, current_player)
    # If target was also updated and it's not the current player, update their state in queue
    updated_queue =
      if target.id != current_player.id do
        TurnQueue.update_character(updated_queue, target)
      else
        updated_queue
      end

    %{
      combat
      | grid: updated_grid,
        players: updated_players,
        queue: updated_queue
    }
  end

  defp update_player_in_list(players, updated_player) do
    Enum.map(players, fn player ->
      if player.id == updated_player.id, do: updated_player, else: player
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
      # Ensure we return to running state if game continues
      {:ok, %Combat{combat | state: :running}}
    end
  end
end
