defmodule Game.Combat.CardEffects.Heal do
  @moduledoc """
  Implements the healing card effect for the CardEffect protocol.
  """

  @behaviour Game.Combat.CardEffect

  alias Game.CombatState
  alias Game.Character

  defstruct type: :heal, value: 0, targeting: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer(),
          targeting: any()
        }

  @impl Game.Combat.CardEffect
  def process(%__MODULE__{value: amount}, target_id, %CombatState{} = combat_state) do
    # Find the target character in the current turn or queue
    target =
      Enum.find([combat_state.current_turn.player | combat_state.queue], fn c ->
        c.id == target_id
      end)

    healed_target = Character.heal(target, amount)

    update_combat_state_with_target(combat_state, healed_target)
  end

  @impl Game.Combat.CardEffect
  def get_description(%__MODULE__{value: amount}) do
    "Heal target for #{amount} HP"
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
