defmodule Game.CombatState do
  use StructAccess

  @moduledoc """
  This module is responsible for implementing pure methods that modify combat state.
  These receive
  """

  require Logger
  alias Game.Card
  alias Game.CombatState
  alias Game.{Character, Grid, TurnQueue}
  alias __MODULE__

  @derive Jason.Encoder

  defstruct state: :initialized,
            # __constants__ is a readonly protected field
            __constants__: %{
              # `players` is a constant meant to store the characters' initial states,
              # allowing procedures like `restore_max_ap` to retrieve information about
              # the default character state and set AP appropriately
              players: []
            },
            # `queue` is the transient value that processes current player state
            # as well as their turn order
            queue: [],
            grid: %Grid{},
            current_turn: %{
              player: nil,
              starting_position: {0, 0, 0},
              card: nil
            },
            # Shop-related state
            shop_cards: []

  @type t() :: %__MODULE__{
          state: atom(),
          __constants__: %{players: list(any())},
          queue: list(any()),
          grid: Grid.t(),
          current_turn: %{
            player: Character.t() | nil,
            starting_position: {0, 0, 0},
            card: Card.t() | nil
          },
          shop_cards: list(Card.t())
        }

  defdelegate process_card(combat, target, card), to: Game.Card

  @doc """
  Initializes a player's turn by ensuring they have 5 cards in their hand.
  Always draws up to 5 cards at the beginning of a turn.
  If draw pile doesn't have enough cards, reshuffles discard pile into draw pile first.
  Returns the updated combat state.
  """
  def initialize_turn(%CombatState{current_turn: %{player: player}} = combat)
      when not is_nil(player) do
    combat
    |> draw_cards_for_player(player, 5)
  end

  # def initialize_turn(combat), do: combat

  # Helper functions for refactored code

  # Move action helpers
  def update_player_position(combat, player, target_position) do
    put_in(combat, [:current_turn, :player], Character.move(player, target_position))
  end

  def update_grid_position(
        %{current_turn: %{player: moved_player}, grid: grid} = combat,
        player,
        target_position
      ) do
    # We need to use the player's original position (before it was updated)
    # as the source position, and the target_position as the destination
    updated_grid = Grid.update_position(grid, moved_player, player.position, target_position)
    %{combat | grid: updated_grid}
  end

  def refresh_grid(%{current_turn: %{player: _current_player}, grid: grid} = combat) do
    updated_grid =
      combat
      |> get_current_queue()
      |> Enum.reduce(grid, fn player, grid ->
        # Check if the position exists in the grid before updating
        if Map.has_key?(grid.tiles, player.position) do
          Grid.update_character(grid, player)
        else
          grid
        end
      end)

    %{combat | grid: updated_grid}
  end

  def update_players_and_queue(%{current_turn: %{player: moved_player}} = combat) do
    updated_queue =
      Enum.map(combat.queue, fn p -> if p.id == moved_player.id, do: moved_player, else: p end)

    # Update the state with new queue
    %{
      combat
      | queue: updated_queue
    }
  end

  def setup_player_turn(%{current_turn: %{player: next_player}} = combat) do
    combat
    |> put_in([:state], :running)
    |> put_in([:current_turn], new_turn(next_player))
    |> draw_cards_for_player(next_player, 5)
    |> restore_max_ap()
  end

  def update_grid_for_player(%{current_turn: %{player: player}} = combat) do
    %{combat | grid: Grid.update_character(combat.grid, player)}
  end

  def check_target_death(combat, target) do
    # Get the current version of the target from combat state
    current_target =
      get_current_queue(combat)
      |> Enum.find(fn char -> char.id == target.id end)
      |> Kernel.||(target)

    updated_target = %{current_target | dead: Character.is_dead?(current_target)}

    combat
    |> update_target(target, updated_target)
  end

  def initialize_queue(%{queue: queue} = combat) do
    [next_player | remaining_queue] = queue

    %{
      combat
      | queue: remaining_queue,
        state: :running,
        current_turn: new_turn(next_player)
    }
  end

  def rotate_queue(%{current_turn: %{player: player}, queue: queue} = combat) do
    # Then rotate the queue and pop the current player
    [next_player | remaining_queue] = queue ++ [player]

    # Update combat state with the next player
    %{
      combat
      | queue: remaining_queue,
        state: :running,
        current_turn: new_turn(next_player)
    }
  end

  def remove_player(%CombatState{grid: grid, queue: queue} = combat, player) do
    %{
      combat
      | grid: Grid.remove_character(grid, player),
        queue: TurnQueue.remove_character(queue, player.id)
    }
  end

  def update_player(
        %CombatState{grid: grid} = combat,
        target,
        current_player
      ) do
    combat
    |> put_in([:grid], Grid.update_character(grid, target))
    |> put_in([:current_turn, :player], current_player)
  end

  def check_game_over(combat) do
    alive_characters =
      combat
      |> get_current_queue()
      |> Enum.filter(&(&1.dead == false))

    alive_teams =
      alive_characters
      |> Enum.map(& &1.team)
      |> Enum.uniq()

    # Remove dead characters from queue
    alive_queue = Enum.filter(combat.queue, &(&1.dead == false))

    # Update current_turn if current player is dead
    updated_current_turn =
      if combat.current_turn.player && combat.current_turn.player.dead do
        %{combat.current_turn | player: nil}
      else
        combat.current_turn
      end

    case length(alive_teams) do
      n when n <= 1 ->
        %{combat | state: :game_over, queue: alive_queue, current_turn: updated_current_turn}

      _ ->
        %{combat | state: :running, queue: alive_queue, current_turn: updated_current_turn}
    end
  end

  @doc """
  Draws cards for a player at the start of their turn up to the default hand size of 5
  If draw pile doesn't have enough cards, reshuffles discard pile into draw pile first
  """
  def draw_cards_for_player(combat, player_character, count \\ 5) do
    updated_character =
      player_character
      |> Character.discard_hand()
      |> maybe_reshuffle_discard(count)
      |> draw_cards(count)

    combat |> put_in([:current_turn, :player], updated_character)
  end

  def maybe_reshuffle_discard(player, count) do
    if length(player.cards.draw) < count && length(player.cards.discard) > 0 do
      Character.shuffle_discard_into_draw(player)
    else
      player
    end
  end

  def draw_cards(player, count) do
    Character.draw_cards(player, count)
  end

  def update_player_in_combat(updated_player, combat) do
    [player | updated_queue] =
      combat
      |> get_current_queue()
      |> TurnQueue.update_character(updated_player)

    combat
    |> put_in([:current_turn, :player], player)
    |> put_in([:queue], updated_queue)
  end

  def new_turn(%Character{position: position} = player) do
    %{
      starting_position: position,
      player: player,
      card: nil
    }
  end

  @doc """
  Gets original character data from the constants
  """
  def get_original_character_data(%CombatState{__constants__: %{players: players}}, player_id) do
    Enum.find(players, &(&1.id == player_id))
  end

  @doc """
  Restores a player's max AP from the original player data in __constants__
  """
  def restore_max_ap(%CombatState{current_turn: %{player: character}} = combat) do
    updated_character = %{character | ap: Game.Character.get_max_ap(character)}

    %{combat | current_turn: %{combat.current_turn | player: updated_character}}
  end

  # TODO: move to Game.Card.Targeting which should process different targeting strategies
  def update_target(combat_state, target, updated_target) do
    all_characters = [get_current_player(combat_state)] ++ combat_state.queue

    [updated_player | updated_queue] =
      Enum.map(all_characters, fn
        possible_target when target.id == possible_target.id -> updated_target
        not_target -> not_target
      end)

    combat_state
    |> put_in([:current_turn, :player], updated_player)
    |> put_in([:queue], updated_queue)
  end

  def get_current_player(%{current_turn: %{player: player}}), do: player
  def get_current_turn(%{current_turn: turn}), do: turn

  def get_current_queue(%CombatState{current_turn: %{player: player}, queue: queue}) do
    [player] ++ queue
  end

  def is_players_turn?(
        %CombatState{current_turn: %{player: %Character{id: current_character_id}}},
        %Character{id: id}
      ) do
    current_character_id == id
  end

  @doc """
  Replaces a player in the combat state by ID, updating both queue and current_turn if necessary.
  Useful for test setup scenarios.
  """
  def replace_player(
        %CombatState{queue: queue, current_turn: current_turn} = combat,
        updated_player
      ) do
    # Update queue
    updated_queue =
      Enum.map(queue, fn p ->
        if p.id == updated_player.id, do: updated_player, else: p
      end)

    # Update current_turn if this is the current player
    updated_current_turn =
      if current_turn.player && current_turn.player.id == updated_player.id do
        %{current_turn | player: updated_player}
      else
        current_turn
      end

    %{combat | queue: updated_queue, current_turn: updated_current_turn}
  end
end
