defmodule Game.Combat.CardEffects.ModifyAttribute do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :modify_attribute,
            attribute: "max_hp",
            value: 0,
            duration: nil,
            value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          attribute: String.t(),
          value: number(),
          duration: integer() | nil,
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.ModifyAttribute

    def process(
          %ModifyAttribute{attribute: attr, value: v, duration: d},
          target,
          %CombatState{} = combat_state
        ) do
      updated_target =
        Character.add_status_effect(target, %{
          type: :modify_attribute,
          attribute: attr,
          value: v,
          duration: d
        })

      CombatState.update_target(combat_state, target, updated_target)
    end

    def get_description(%ModifyAttribute{attribute: attr, value: v, duration: nil}),
      do: "Modify #{attr} by #{v} permanently"

    def get_description(%ModifyAttribute{attribute: attr, value: v, duration: d}),
      do: "Modify #{attr} by #{v} for #{d} turns"

    def get_icon(%ModifyAttribute{}), do: "hero-adjustments-horizontal-mini"

    def get_value_label(%ModifyAttribute{value_label: label}) when is_binary(label), do: label
    def get_value_label(%ModifyAttribute{value: v}), do: "#{v}"

    def animate(%ModifyAttribute{value: v}) when v >= 0, do: %{label: "BUFF", color: :green}
    def animate(%ModifyAttribute{}), do: %{label: "DEBUFF", color: :yellow}

    def params(_), do: ["attribute", "value", "duration"]
  end
end
