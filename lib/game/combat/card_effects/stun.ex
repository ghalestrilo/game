defmodule Game.Combat.CardEffects.Stun do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :stun, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Stun

    # Store value + 1 so that ticking from n to 0 results in n skipped turns
    def process(%Stun{value: duration}, target, %CombatState{} = combat_state) do
      updated_target = Character.add_status_effect(target, %{type: :stun, value: duration + 1})
      CombatState.update_target(combat_state, target, updated_target)
    end

    def get_description(%Stun{value: v}), do: "Stun target for #{v} turns"
    def get_icon(%Stun{}), do: "hero-bolt-slash-mini"

    def get_value_label(%Stun{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Stun{value: v}), do: "#{v}"

    def params(_), do: ["value"]

    def animate(%Stun{}), do: %{label: "STUNNED", color: :yellow}
  end
end
