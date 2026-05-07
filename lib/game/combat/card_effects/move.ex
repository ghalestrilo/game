defmodule Game.Combat.CardEffects.Move do
  alias Game.CombatState
  alias Game.{Character, Grid}

  @derive Jason.Encoder
  defstruct type: :move, angle: 0, distance: 1, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          angle: integer() | map(),
          distance: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Move

    def process(%Move{angle: angle, distance: distance}, target, %CombatState{} = combat_state)
        when not is_nil(angle) and is_integer(angle) do
      {dq, dr, ds} = Grid.direction_from_angle(angle)
      new_pos = {target.position |> elem(0) |> Kernel.+(dq * distance),
                 target.position |> elem(1) |> Kernel.+(dr * distance),
                 target.position |> elem(2) |> Kernel.+(ds * distance)}

      #  FIXME: use first_unblocked_tile
      if Map.has_key?(combat_state.grid.tiles, new_pos) and
           not Grid.tile_blocked?(combat_state.grid, new_pos) do
        updated_target = Character.move(target, new_pos)

        updated_grid =
          Grid.update_position(combat_state.grid, updated_target, target.position, new_pos)

        combat_state
        |> CombatState.update_target(target, updated_target)
        |> Map.put(:grid, updated_grid)
      else
        combat_state
      end
    end

    def process(%Move{}, _target, %CombatState{} = combat_state), do: combat_state

    # TODO: we need to implement this to avoid issues with "cast_distance" not moving the target.
    def first_unblocked_tile() do
      nil
    end

    def get_description(%Move{angle: angle, distance: distance}) do
      "Move target #{distance} tile(s) in direction #{angle}"
    end

    def get_icon(%Move{}), do: "hero-arrows-pointing-out-mini"

    def get_value_label(%Move{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Move{distance: d}), do: "#{d}"

    def animate(%Move{}), do: %{label: "MOVE", color: :blue}

    def params(_), do: ["angle", "distance"]
  end
end
