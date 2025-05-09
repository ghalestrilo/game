defmodule Game do
  alias __MODULE__

  require Logger

  @initial_state %{
    grid: %Game.Grid{},
    characters: [
      %Game.Character{},
      %Game.Character{}
    ],
    combat: %Game.Combat{}
  }
  @doc """
  This module implements a turn-based combat system via a GenServer

  The rules of the game are defined in the `Game.Combat` module.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  # Initialize combat with a random grid with two characters
  def init(opts) do
    {:ok, @initial_state}
  end
end
