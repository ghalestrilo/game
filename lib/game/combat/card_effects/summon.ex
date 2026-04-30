defmodule Game.Combat.CardEffects.Summon do
  @moduledoc """
  Summons a character from a class name at a target position.
  - Loads character data from database by class name
  - Adds character to combat queue at the end
  - Character belongs to same team as summoner
  """

  alias Game.CombatState
  alias Game.{Character, Content}

  defstruct type: :summon, value: nil, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: String.t() | nil,
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Summon
    alias Game.{Character, Content, CombatState}

    @impl Game.Combat.CardEffect
    def process(
          %Summon{value: class_name} = _effect,
          target_position,
          %CombatState{} = combat_state
        )
        when is_tuple(target_position) do
      current_player = CombatState.get_current_player(combat_state)

      # Load the base class from database
      base_class = Content.get_base_class_by_class!(class_name)

      # Create a new character from the base class
      summoned_character =
        base_class
        |> Character.from_character_data()
        |> Map.put(:position, target_position)
        |> Map.put(:team, current_player.team)
        |> Map.put(:id, generate_unique_id(combat_state))

      # Add character to the queue at the end
      updated_queue = combat_state.queue ++ [summoned_character]

      # Update the grid with the new character
      updated_grid = %{
        combat_state.grid
        | tiles:
            Map.update!(
              combat_state.grid.tiles,
              target_position,
              &%{&1 | occupied_by: summoned_character}
            )
      }

      %{combat_state | queue: updated_queue, grid: updated_grid}
    end

    @impl Game.Combat.CardEffect
    def get_description(%Summon{value: class_name}) do
      "Summon a #{class_name} at target tile"
    end

    @impl Game.Combat.CardEffect
    def get_icon(%Summon{}), do: "hero-user-plus-mini"

    @impl Game.Combat.CardEffect
    def get_value_label(%Summon{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Summon{value: class_name}), do: class_name

    def animate(_), do: nil

    # Generate a unique ID for the summoned character
    defp generate_unique_id(combat_state) do
      all_characters = [combat_state.current_turn.player | combat_state.queue]
      existing_ids = Enum.map(all_characters, & &1.id)
      max_id = Enum.max(existing_ids, fn -> 0 end)
      max_id + 1
    end
  end
end
