defmodule Game.Combat.CardEffects.Regen do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :regen, value: 0, heal: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          heal: integer(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Regen

    @impl Game.Combat.CardEffect
    def process(%Regen{value: duration, heal: amount}, target, %CombatState{} = combat_state) do
      updated_target =
        Character.add_status_effect(target, %{type: :regen, heal: amount, value: duration})

      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Regen{heal: h, value: v}),
      do: "Restore #{h} HP per turn for #{v} turns"

    @impl Game.Combat.CardEffect
    def get_icon(%Regen{}), do: "hero-heart-solid"

    @impl Game.Combat.CardEffect
    def get_value_label(%Regen{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Regen{heal: h}), do: "#{h}/turn"

    @impl Game.Combat.CardEffect
    def animate(%Regen{heal: h}), do: %{label: "+#{h}/turn", color: :green}

    @impl Game.Combat.CardEffect
    def params(_), do: ["value", "heal"]
  end
end
