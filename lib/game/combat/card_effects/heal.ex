defmodule Game.Combat.CardEffects.Heal do
  @moduledoc """
  Implements the heal card effect for the CardEffect protocol.
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :heal,
            value: 0,
            targeting: %{
              "type" => "character",
              "rule" => %{"var" => "target.occupied"}
            }

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer(),
          targeting: map() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Heal

    @impl Game.Combat.CardEffect
    def process(%Heal{value: amount} = _effect, target, %CombatState{} = combat_state) do
      CombatState.update_target(combat_state, target, Character.apply_healing(target, amount))
    end

    @impl Game.Combat.CardEffect
    def get_description(%Heal{value: amount}) do
      "Restores #{amount} hp to target"
    end
  end
end
