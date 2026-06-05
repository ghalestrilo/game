defmodule Game.Combat.CardEffects.Cleanse do
  alias Game.CombatState

  @derive Jason.Encoder
  defstruct type: :cleanse, value: nil, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: nil,
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Cleanse

    @negative_effects [:stuck, :slow, :stun, :dot]

    @impl Game.Combat.CardEffect
    def process(%Cleanse{}, target, %CombatState{} = combat_state) do
      updated_target = %{
        target
        | status_effects: Enum.reject(target.status_effects, &(&1.type in @negative_effects))
      }

      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Cleanse{}), do: "Remove all negative status effects"
    @impl Game.Combat.CardEffect
    def get_icon(%Cleanse{}), do: "hero-sparkles-solid"

    @impl Game.Combat.CardEffect
    def get_value_label(%Cleanse{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Cleanse{}), do: ""

    @impl Game.Combat.CardEffect
    def animate(%Cleanse{}), do: %{label: "CLEANSE", color: :green}

    @impl Game.Combat.CardEffect
    def params(_), do: []
  end
end
