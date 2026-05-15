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
              movement_remaining: nil,
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
            movement_remaining: integer() | nil,
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
    |> draw_cards_for_player(player)
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
    ticked =
      combat
      |> put_in([:state], :running)
      |> put_in([:current_turn], new_turn(next_player))
      |> tick_status_effects()

    if stun_active?(ticked.current_turn.player) do
      ticked |> rotate_queue() |> setup_player_turn()
    else
      ticked
      |> draw_cards_for_player(ticked.current_turn.player)
      |> restore_max_ap()
    end
  end

  defp stun_active?(player) do
    case Character.get_status_effect(player, :stun) do
      %{value: v} when v > 0 -> true
      _ -> false
    end
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
        result = %{combat | state: :game_over, queue: alive_queue, current_turn: updated_current_turn}
        Task.start(fn -> Game.Events.Publisher.publish_game_over(result) end)
        result

      _ ->
        %{combat | state: :running, queue: alive_queue, current_turn: updated_current_turn}
    end
  end

  @doc """
  Draws cards for a player at the start of their turn up to the default hand size of 5
  If draw pile doesn't have enough cards, reshuffles discard pile into draw pile first
  """
  def draw_cards_for_player(combat, player_character, count \\ nil) do
    count = count || Character.effective_attribute(player_character, "hand_size")

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
      movement_remaining: nil,
      player: player,
      card: nil
    }
  end

  def deduct_movement(combat, distance) do
    update_in(combat, [:current_turn, :movement_remaining], &(&1 - distance))
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
    updated_character = %{character | ap: Game.Character.effective_attribute(character, "max_ap")}

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

  def tick_status_effects(%CombatState{current_turn: %{player: player}} = combat) do
    # Step 1: apply per-turn triggers (dot damage, regen healing)
    player_after_triggers =
      Enum.reduce(player.status_effects, player, fn effect, acc ->
        case effect do
          %{type: :dot, damage: dmg, value: v} when v > 0 ->
            Character.apply_damage(acc, dmg)

          %{type: :regen, heal: h, value: v} when v > 0 ->
            %{acc | hp: min(acc.hp + h, Character.effective_attribute(acc, "max_hp"))}

          _ ->
            acc
        end
      end)

    # Step 2: decrement durations and remove expired effects
    updated_effects =
      player_after_triggers.status_effects
      |> Enum.map(fn
        %{type: :stealth, value: v} = e -> %{e | value: v - 1}
        %{type: :ethereal, value: v} = e -> %{e | value: v - 1}
        %{type: :stuck, value: v} = e -> %{e | value: v - 1}
        %{type: :stun, value: v} = e -> %{e | value: v - 1}
        %{type: :hex, value: v} = e -> %{e | value: v - 1}
        %{type: :dot, value: v} = e -> %{e | value: v - 1}
        %{type: :regen, value: v} = e -> %{e | value: v - 1}
        %{type: :slow, duration: d} = e when is_integer(d) -> %{e | duration: d - 1}
        %{type: :modify_attribute, duration: d} = e when is_integer(d) -> %{e | duration: d - 1}
        effect -> effect
      end)
      |> Enum.reject(fn
        %{type: :slow, duration: d} when is_integer(d) -> d <= 0
        %{type: :modify_attribute, duration: d} when is_integer(d) -> d <= 0
        %{value: v} -> v <= 0
        _ -> false
      end)

    updated_player = %{player_after_triggers | status_effects: updated_effects}
    put_in(combat, [:current_turn, :player], updated_player)
  end

  def dispel_stealth(%CombatState{current_turn: %{player: player}} = combat) do
    updated_effects = Enum.reject(player.status_effects, &(&1.type in [:stealth, :ethereal]))
    updated_player = %{player | status_effects: updated_effects}
    put_in(combat, [:current_turn, :player], updated_player)
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
