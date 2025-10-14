defmodule Game.Tile do
  defstruct [
    # Type of terrain (plain, water, obstacle, etc.)
    :terrain,
    # Character ID if occupied
    :occupied_by
  ]
end
