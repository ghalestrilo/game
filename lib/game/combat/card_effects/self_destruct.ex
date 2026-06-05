defmodule Game.Combat.CardEffects.SelfDestruct do
  alias Game.CombatState

  @derive Jason.Encoder
  defstruct type: :self_destruct, value: nil, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: nil,
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.SelfDestruct

    # The played card is already in the current player's discard (moved there by process_card/3
    # before effects run). Remove it so the card is gone from the deck entirely.
    def process(
          %SelfDestruct{},
          _target,
          %CombatState{current_turn: %{card: played_card}} = combat_state
        )
        when not is_nil(played_card) do
      player = CombatState.get_current_player(combat_state)

      updated_discard =
        Enum.reject(player.cards.discard, &(&1.id == played_card.id))

      updated_player = put_in(player.cards.discard, updated_discard)

      CombatState.update_target(combat_state, player, updated_player)
    end

    @impl Game.Combat.CardEffect
    def process(%SelfDestruct{}, _target, combat_state), do: combat_state

    @impl Game.Combat.CardEffect
    def get_description(%SelfDestruct{}), do: "Remove this card from your deck permanently"
    @impl Game.Combat.CardEffect
    def get_icon(%SelfDestruct{}), do: "hero-fire-solid"

    @impl Game.Combat.CardEffect
    def get_value_label(%SelfDestruct{value_label: label}) when is_binary(label), do: label
    def get_value_label(%SelfDestruct{}), do: ""

    @impl Game.Combat.CardEffect
    def animate(%SelfDestruct{}), do: %{label: "GONE", color: :red}

    @impl Game.Combat.CardEffect
    def params(_), do: []
  end
end
