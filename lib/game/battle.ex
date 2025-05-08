defmodule Game.Battle do
  defstruct [
    :id,
    # List of characters participating
    :characters,
    # Battle grid
    :grid
  ]
end
