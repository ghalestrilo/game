defmodule Game.Combat.CardEffects.Revive do
  alias Game.CombatState

  @derive Jason.Encoder
  defstruct type: :revive, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Revive

    def process(%Revive{}, %{dead: false}, %CombatState{} = combat_state), do: combat_state

    def process(%Revive{value: hp}, target, %CombatState{} = combat_state) do
      revived = %{target | dead: false, hp: max(hp, 1)}
      CombatState.update_target(combat_state, target, revived)
    end

    def get_description(%Revive{value: v}), do: "Revive target with #{v} HP"
    def get_icon(%Revive{}), do: "hero-arrow-up-circle"
    def get_value_label(%Revive{value_label: l}) when is_binary(l), do: l
    def get_value_label(%Revive{value: v}), do: "#{v}"
    @impl Game.Combat.CardEffect
    def animate(%Revive{value: v}), do: %{label: "REVIVED +#{v}", color: :green}
    @impl Game.Combat.CardEffect
    def params(_), do: ["value"]
  end
end
