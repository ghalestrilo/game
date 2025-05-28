defmodule Game do
  alias __MODULE__
  alias Game.Combat

  require Logger

  @initial_state %{
    grid: Game.Grid.new({2, 2, 2}),  # Creates a 5x5x5 hex grid centered at (0,0,0)
    characters: [
      %Game.Character{},
      %Game.Character{}
    ],
    combat: %Game.Combat{}
  }

  @doc """
  This module implements a turn-based combat system via a GenServer.
  Each instance represents a separate game running concurrently.

  The rules of the game are defined in the `Game.Combat` module.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  # Initialize combat with a random grid with two characters
  def init(_opts) do
    {:ok, @initial_state}
  end

  @doc """
  Initializes a new combat match with the given characters and grid.
  """
  def init_combat(game_pid, characters, grid) do
    GenServer.call(game_pid, {:init_combat, characters, grid})
  end

  @doc """
  Makes a character move to a new position.
  Returns {:ok, updated_state} or {:error, reason}
  """
  def move_character(game_pid, character, target_position) do
    GenServer.call(game_pid, {:move, character, target_position})
  end

  @doc """
  Plays a card from a character's hand.
  Returns {:ok, updated_state} or {:error, reason}
  """
  def play_card(game_pid, character, card, target_position) do
    GenServer.call(game_pid, {:play_card, character, card, target_position})
  end

  @doc """
  Gets the current state of the game.
  """
  def get_state(game_pid) do
    GenServer.call(game_pid, :get_state)
  end

  # Callbacks

  def handle_call({:init_combat, characters, grid}, _from, _state) do
    # Initialize a 6x6 grid if none provided
    grid = if grid == %Game.Grid{}, do: Game.Grid.new({3, 3, 3}), else: grid

    combat = %Combat{
      state: :running,
      players: characters,
      queue: characters,
      grid: grid,
      current_turn: %{starting_position: hd(characters).position}
    }

    new_state = %{grid: grid, characters: characters, combat: combat}
    {:reply, {:ok, combat}, new_state}
  end

  def handle_call({:move, character, target_position}, _from, state) do
    # Get the latest version of the character from state
    current_character = Enum.find(state.combat.players, &(&1.id == character.id))

    case Combat.act(state.combat, {:move, current_character, target_position}) do
      {:ok, updated_combat} ->
        {:reply, {:ok, updated_combat}, %{state | combat: updated_combat}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:play_card, character, card, target_position}, _from, state) do
    # Get the latest version of the character from state
    current_character = Enum.find(state.combat.players, &(&1.id == character.id))

    # Check if it's the character's turn
    [current_turn | _] = state.combat.queue

    if current_turn.id != current_character.id do
      {:reply, {:error, "Not player's turn"}, state}
    else
      case Combat.act(state.combat, {:play_card, current_character, card, target_position}) do
        {:ok, updated_combat} ->
          current_character = Enum.find(updated_combat.players, &(&1.id == current_character.id))
          # Update the character's state in the game state
          updated_state = %{state | combat: updated_combat}
          {:reply, {:ok, updated_combat}, updated_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
