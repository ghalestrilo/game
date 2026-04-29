defmodule Game.Combat.CardEffects.Draw do
  @moduledoc """
  Implements the draw card effect for the CardEffect protocol.
  Draws cards from the draw pile into the character's hand.
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :draw, value: 0, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Draw

    @impl Game.Combat.CardEffect
    def process(%Draw{value: count} = _effect, target, %CombatState{} = combat_state) do
      updated_target = Character.draw_cards(target, count)
      CombatState.update_target(combat_state, target, updated_target)
    end

    @impl Game.Combat.CardEffect
    def get_description(%Draw{value: count}) do
      "Draw #{count} card#{if count != 1, do: "s", else: ""}"
    end

    @impl Game.Combat.CardEffect
    def get_icon(%Draw{}), do: "hero-squares-2x2-mini"

    @impl Game.Combat.CardEffect
    def get_value_label(%Draw{value: count}), do: "#{count} card#{if count != 1, do: "s", else: ""}"
  end
end
