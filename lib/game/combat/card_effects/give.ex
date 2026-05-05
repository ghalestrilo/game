defmodule Game.Combat.CardEffects.Give do
  alias Game.CombatState

  @derive Jason.Encoder
  defstruct type: :give, value: nil, card: nil, pile: "hand", value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: nil,
          card: integer() | nil,
          pile: String.t(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Give

    def process(%Give{card: card_id, pile: pile}, target, %CombatState{} = combat_state)
        when is_integer(card_id) do
      pile_atom = pile_to_atom(pile)

      with base_card <- Game.BaseCards.get_base_card!(card_id),
           game_card <- base_card_to_card(base_card) do
        updated_cards =
          Map.update!(target.cards, pile_atom, &[game_card | &1])

        updated_target = %{target | cards: updated_cards}
        CombatState.update_target(combat_state, target, updated_target)
      end
    end

    def process(%Give{}, _target, combat_state), do: combat_state

    def get_description(%Give{pile: pile}), do: "Give target a card into their #{pile}"
    def get_icon(%Give{}), do: "hero-gift-mini"

    def get_value_label(%Give{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Give{}), do: ""

    def animate(%Give{}), do: %{label: "GIVE", color: :blue}

    def params(_), do: ["card", "pile"]

    defp pile_to_atom("draw"), do: :draw
    defp pile_to_atom("hand"), do: :hand
    defp pile_to_atom("discard"), do: :discard
    defp pile_to_atom(_), do: :hand

    defp base_card_to_card(base_card) do
      card_map =
        base_card
        |> Map.from_struct()
        |> Map.drop([:__meta__, :inserted_at, :updated_at, :ap, :headline])
        |> Map.merge(%{cost: base_card.ap, id: -base_card.id})

      struct!(Game.Card, card_map)
    end
  end
end
