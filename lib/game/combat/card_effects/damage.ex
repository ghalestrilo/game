defmodule Game.Combat.CardEffects.Damage do
  @moduledoc """
  Implements the damage card effect for the CardEffect protocol.
  """

  alias Game.CombatState
  alias Game.Character

  defstruct type: :damage, value: 0, targeting: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer(),
          targeting: any()
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Damage

    def process(%Damage{value: amount}, target, %CombatState{} = combat_state) do
      dbg(target)
      CombatState.update_target(combat_state, target, Character.apply_damage(target, amount))
    end

    @impl Game.Combat.CardEffect
    def get_description(%Damage{value: amount}) do
      "Deal #{amount} damage to target"
    end

    defp update_combat_state_with_target(combat_state, updated_target) do
      # Update current_turn.player if it's the target
      combat_state =
        if combat_state.current_turn.player.id == updated_target.id do
          %{combat_state | current_turn: %{combat_state.current_turn | player: updated_target}}
        else
          combat_state
        end

      # Update the queue
      updated_queue =
        Enum.map(combat_state.queue, fn c ->
          if c.id == updated_target.id, do: updated_target, else: c
        end)

      %{combat_state | queue: updated_queue}
    end
  end
end
