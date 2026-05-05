defmodule Game.Combat.CardEffects.Dot do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :dot, value: 0, damage: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          damage: integer(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Dot

    def process(%Dot{value: duration, damage: dmg}, target, %CombatState{} = combat_state) do
      updated_target =
        Character.add_status_effect(target, %{type: :dot, damage: dmg, value: duration})

      CombatState.update_target(combat_state, target, updated_target)
    end

    def get_description(%Dot{damage: dmg, value: v}),
      do: "Deal #{dmg} damage per turn for #{v} turns"

    def get_icon(%Dot{}), do: "hero-fire-mini"

    def get_value_label(%Dot{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Dot{damage: dmg}), do: "#{dmg}/turn"

    def animate(%Dot{damage: dmg}), do: %{label: "-#{dmg}/turn", color: :red}

    def params(_), do: ["value", "damage"]
  end
end
