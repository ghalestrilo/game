defmodule Game.Tile do
  defstruct terrain: :plain,
            occupied_by: nil,
            objects: []
end
