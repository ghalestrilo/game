defmodule Game.MapObject.Breakable do
  defstruct hp: 1, max_hp: 1, blocks_movement: true

  defimpl Game.MapObject do
    def blocks_movement?(%{hp: hp, blocks_movement: blocks}) when hp > 0, do: blocks
    def blocks_movement?(_breakable), do: false

    def on_enter(_breakable, _character, combat_state), do: {:ok, combat_state}
  end
end
