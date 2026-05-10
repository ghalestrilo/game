defmodule Game.Combat.CardEffects.Stealth do
  @moduledoc """
  Implements the stealth card effect for the CardEffect protocol.
  Adds a stealth status effect to the target character.
  The stored duration is value + 1 to account for the current turn.
  Stealth is dispelled when the hidden character plays any card.
  """

  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :stealth, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Stealth

    @impl Game.Combat.CardEffect
    def process(%Stealth{value: duration} = _effect, target, %CombatState{} = combat_state) do
      stealth_status = %{type: :stealth, value: duration + 1}
      updated_target = Character.add_status_effect(target, stealth_status)
      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Stealth{value: v}) do
      "Become hidden for #{v + 1} turns"
    end

    @impl Game.Combat.CardEffect
    def get_icon(%Stealth{}), do: "hero-eye-slash-solid"

    @impl Game.Combat.CardEffect
    def get_value_label(%Stealth{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Stealth{value: v}), do: "#{v}"

    def params(_), do: ["value"]

    def animate(%Stealth{}), do: %{label: "HIDDEN", color: :yellow}
  end
end
