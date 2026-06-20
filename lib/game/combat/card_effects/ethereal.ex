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

    @impl Game.Combat.CardEffect
    def process(%Ethereal{value: duration}, target, %CombatState{} = combat_state) do
      updated_target =
        Character.add_status_effect(target, %{type: :ethereal, value: duration})

      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Ethereal{value: v}),
      do: "Become untargetable for #{v + 1} turns. Dispels on cast."

    @impl Game.Combat.CardEffect
    def get_icon(%Ethereal{}), do: "hero-cube-transparent-solid"

    @impl Game.Combat.CardEffect
    def get_value_label(%Ethereal{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Ethereal{value: v}), do: "#{v}"

    @impl Game.Combat.CardEffect
    def params(_), do: ["value"]

    @impl Game.Combat.CardEffect
    def animate(%Ethereal{}), do: %{label: "ETHEREAL", color: :blue}
  end
end
