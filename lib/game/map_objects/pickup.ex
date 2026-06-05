defmodule Game.MapObject.Pickup do
  @derive Jason.Encoder
  defstruct item: nil, quantity: 1

  defimpl Game.MapObject do
    def blocks_movement?(_pickup), do: false

    def on_enter(%{item: item, quantity: qty}, _character, combat_state),
      do: {:collect, item, qty, combat_state}
  end
end
