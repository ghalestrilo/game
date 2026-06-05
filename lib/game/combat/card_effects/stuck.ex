defmodule Game.Combat.CardEffects.Stuck do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :stuck, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Stuck

    @impl Game.Combat.CardEffect
    def process(%Stuck{value: duration}, target, %CombatState{} = combat_state) do
      updated_target = Character.add_status_effect(target, %{type: :stuck, value: duration})
      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Stuck{value: v}), do: "Target is stuck for #{v} turns"
    @impl Game.Combat.CardEffect
    def get_icon(%Stuck{}), do: "hero-no-symbol-solid"

    @impl Game.Combat.CardEffect
    def get_value_label(%Stuck{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Stuck{value: v}), do: "#{v}"

    @impl Game.Combat.CardEffect
    def params(_), do: ["value"]

    @impl Game.Combat.CardEffect
    def animate(%Stuck{}), do: %{label: "STUCK", color: :yellow}
  end
end
