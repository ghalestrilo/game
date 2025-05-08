defmodule Game do
  alias __MODULE__

  require Logger

  @doc """
  This module implements a turn-based combat system via a GenServer

  The rules of the game are defined in the `Game.Combat` module.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {:ok, opts}
  end
end
