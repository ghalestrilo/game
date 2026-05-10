defmodule Game.Combat.CardEffects.Discard do
  @moduledoc """
  Implements the discard card effect for the CardEffect protocol.
  Discards cards from the target's hand into their discard pile.
  """

  alias Game.CombatState

  defstruct type: :discard, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Discard

    @impl Game.Combat.CardEffect
    def process(%Discard{value: count} = _effect, target, %CombatState{} = combat_state) do
      updated_target = discard_random_cards(target, count)
      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Discard{value: count}) do
      "Discard #{count} card#{if count != 1, do: "s", else: ""} from target's hand"
    end

    @impl Game.Combat.CardEffect
    def get_icon(%Discard{}), do: "hero-trash-solid"

    @impl Game.Combat.CardEffect
    def get_value_label(%Discard{value: count}),
      do: "#{count} card#{if count != 1, do: "s", else: ""}"

    def params(_), do: ["value"]

    def animate(_), do: nil

    defp discard_random_cards(character, count) do
      hand = character.cards.hand
      cards_to_discard_count = min(count, length(hand))

      {cards_to_discard, remaining_hand} = Enum.split(Enum.shuffle(hand), cards_to_discard_count)

      %{
        character
        | cards: %{
            character.cards
            | hand: remaining_hand,
              discard: character.cards.discard ++ cards_to_discard
          }
      }
    end
  end
end
