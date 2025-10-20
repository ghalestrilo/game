defmodule Game.Combat.CardEffects.Summon do
  @moduledoc """
  Initializes a character from character_data
  - maintains same :player_id
  - added to end of queue
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :heal, value: 0, targeting: nil, character: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer(),
          targeting: any()
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Summon

    def process(%Summon{character: character} = effect, target, %CombatState{} = combat_state) do
      # WIP
      # CombatState.update_target(combat_state, target, Character.apply_healing(target, amount))
    end

    @impl Game.Combat.CardEffect
    def get_description(%Summon{character: character}) do
      "[WIP] Summons a #{character.name} at seleted tile"
    end
  end
end
