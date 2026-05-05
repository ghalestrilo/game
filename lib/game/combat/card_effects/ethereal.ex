defmodule Game.Combat.CardEffects.Ethereal do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :ethereal, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Ethereal

    # Store value + 1 to account for the current turn, matching stealth behavior
    def process(%Ethereal{value: duration}, target, %CombatState{} = combat_state) do
      updated_target = Character.add_status_effect(target, %{type: :ethereal, value: duration + 1})
      CombatState.update_target(combat_state, target, updated_target)
    end

    def get_description(%Ethereal{value: v}),
      do: "Become untargetable for #{v + 1} turns. Dispels on cast."

    def get_icon(%Ethereal{}), do: "hero-eye-slash-mini"

    def get_value_label(%Ethereal{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Ethereal{value: v}), do: "#{v}"

    def animate(%Ethereal{}), do: %{label: "ETHEREAL", color: :blue}
  end
end
