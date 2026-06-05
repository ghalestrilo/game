defmodule Game.Combat.CardEffects.Slow do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :slow, value: 0, duration: nil, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          duration: integer() | nil,
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Slow

    def process(
          %Slow{value: reduction, duration: duration},
          target,
          %CombatState{} = combat_state
        ) do
      updated_target =
        Character.add_status_effect(target, %{type: :slow, value: reduction, duration: duration})

      CombatState.update_target(combat_state, target, updated_target)
    end

    def get_description(%Slow{value: v, duration: nil}),
      do: "Reduce target's movement by #{v} permanently"

    def get_description(%Slow{value: v, duration: d}),
      do: "Reduce target's movement by #{v} for #{d} turns"

    def get_icon(%Slow{}), do: "hero-arrow-down-solid"

    def get_value_label(%Slow{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Slow{value: v}), do: "#{v}"

    @impl Game.Combat.CardEffect
    def animate(%Slow{}), do: %{label: "SLOW", color: :yellow}

    @impl Game.Combat.CardEffect
    def params(_), do: ["value", "duration"]
  end
end
