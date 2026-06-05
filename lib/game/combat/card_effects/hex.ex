defmodule Game.Combat.CardEffects.Hex do
  alias Game.CombatState
  alias Game.Character

  @derive Jason.Encoder
  defstruct type: :hex, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Hex

    def process(%Hex{value: duration}, target, %CombatState{} = combat_state) do
      updated_target = Character.add_status_effect(target, %{type: :hex, value: duration})
      CombatState.update_target(combat_state, target, updated_target)
    end

    def get_description(%Hex{value: v}),
      do: "Hex target for #{v} turns (inverts damage and healing)"

    def get_icon(%Hex{}), do: "hero-arrow-path-rounded-square-solid"

    def get_value_label(%Hex{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Hex{value: v}), do: "#{v}"

    @impl Game.Combat.CardEffect
    def animate(%Hex{}), do: %{label: "HEX", color: :yellow}

    @impl Game.Combat.CardEffect
    def params(_), do: ["value"]
  end
end
