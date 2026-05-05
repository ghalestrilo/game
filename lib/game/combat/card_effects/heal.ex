defmodule Game.Combat.CardEffects.Heal do
  @moduledoc """
  Implements the heal card effect for the CardEffect protocol.
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :heal, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Heal

    @impl Game.Combat.CardEffect
    def process(%Heal{value: amount} = _effect, target, %CombatState{} = combat_state) do
      CombatState.update_target(
        combat_state,
        target,
        Character.apply_damage(target, amount * -1)
      )
    end

    @impl Game.Combat.CardEffect
    def get_description(%Heal{value: amount}) do
      "Restores #{amount} hp to target"
    end

    @impl Game.Combat.CardEffect
    def get_icon(%Heal{}), do: "hero-arrow-up-mini"

    @impl Game.Combat.CardEffect
    def get_value_label(%Heal{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Heal{value: v}), do: "#{v}"

    def animate(%Heal{value: v}), do: %{label: "+#{v}", color: :green}
  end
end
