defmodule Game.Combat.CardEffects.Damage do
  @moduledoc """
  Implements the damage card effect for the CardEffect protocol.
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :damage, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Damage

    @impl Game.Combat.CardEffect
    def process(%Damage{value: amount} = _effect, target, %CombatState{} = combat_state) do
      CombatState.update_target(combat_state, target, Character.apply_damage(target, amount))
    end

    @impl Game.Combat.CardEffect
    def get_description(%Damage{value: amount}) do
      "Deal #{amount} damage to target"
    end

    @impl Game.Combat.CardEffect
    def get_icon(%Damage{}), do: "hero-bolt-mini"

    @impl Game.Combat.CardEffect
    def get_value_label(%Damage{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Damage{value: v}), do: "#{v}"
  end
end
