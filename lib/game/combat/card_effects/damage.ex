defmodule Game.Combat.CardEffects.Damage do
  @moduledoc """
  Implements the damage card effect for the CardEffect protocol.
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :damage, value: 0, targeting: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer(),
          targeting: any()
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Damage

    def process(%Damage{value: amount} = effect, target, %CombatState{} = combat_state) do
      CombatState.update_target(combat_state, target, Character.apply_damage(target, amount))
    end

    @impl Game.Combat.CardEffect
    def get_description(%Damage{value: amount}) do
      "Deal #{amount} damage to target"
    end
  end
end
