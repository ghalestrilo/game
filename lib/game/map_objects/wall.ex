defmodule Game.MapObject.Wall do
  @derive Jason.Encoder
  defstruct []

  defimpl Game.MapObject do
    def blocks_movement?(_wall), do: true
    def on_enter(_wall, _character, combat_state), do: {:ok, combat_state}
  end
end
