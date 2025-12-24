defmodule Game.Combat.CardEffects.Shield do
  @moduledoc """
  Implements the shield card effect for the CardEffect protocol.
  Adds a shield status effect to the target character.
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :shield,
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
    alias Game.Combat.CardEffects.Shield

    @impl Game.Combat.CardEffect
    def process(%Shield{value: amount} = _effect, target, %CombatState{} = combat_state) do
      shield_status = %{type: :shield, value: amount}
      updated_target = Character.add_status_effect(target, shield_status)
      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Shield{value: amount}) do
      "Grant #{amount} shield to target"
    end
  end
end
