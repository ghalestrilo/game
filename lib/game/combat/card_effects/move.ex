defmodule Game.Combat.CardEffects.Move do
  alias Game.CombatState
  alias Game.{Character, Grid}

  @derive Jason.Encoder
  defstruct type: :move, angle: 0, distance: 1, value_label: nil, trajectory: nil

  @type t() :: %__MODULE__{
          type: atom(),
          angle: integer() | map(),
          distance: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Move

    def process(%Move{angle: angle, distance: distance, trajectory: trajectory}, target, %CombatState{} = combat_state)
        when not is_nil(angle) and is_integer(angle) and trajectory in [:linear, "linear"] do
      grid = combat_state.grid
      {dq, dr, ds} = Grid.direction_from_angle(angle)
      {tq, tr, ts} = target.position
      dest = {tq + dq * distance, tr + dr * distance, ts + ds * distance}

      if Grid.has_linear_path?(grid, target.position, dest) and
           Map.has_key?(grid.tiles, dest) and
           not Grid.tile_blocked?(grid, dest) do
        new_grid = Grid.update_position(grid, target, target.position, dest)
        new_target = Character.move(target, dest)
        combat_state
        |> CombatState.update_target(target, new_target)
        |> Map.put(:grid, new_grid)
      else
        combat_state
      end
    end

    def process(%Move{angle: angle, distance: distance, trajectory: trajectory}, target, %CombatState{} = combat_state)
        when not is_nil(angle) and is_integer(angle) and trajectory in [:null, "null"] do
      grid = combat_state.grid
      {dq, dr, ds} = Grid.direction_from_angle(angle)
      {tq, tr, ts} = target.position
      dest = {tq + dq * distance, tr + dr * distance, ts + ds * distance}

      if Map.has_key?(grid.tiles, dest) do
        new_grid = Grid.update_position(grid, target, target.position, dest)
        new_target = Character.move(target, dest)
        combat_state
        |> CombatState.update_target(target, new_target)
        |> Map.put(:grid, new_grid)
      else
        combat_state
      end
    end

    def process(%Move{angle: angle, distance: distance}, target, %CombatState{} = combat_state)
        when not is_nil(angle) and is_integer(angle) do
      caster = combat_state.current_turn.player
      grid = combat_state.grid

      {final_target, final_grid} =
        if target.id == caster.id do
          do_move_fixed(grid, Grid.direction_from_angle(angle), target, distance)
        else
          given_dir = Grid.direction_from_angle(angle)
          pull_dir = Grid.direction_toward(grid, target.position, caster.position)
          mode = if given_dir == pull_dir, do: :pull, else: :push
          do_move_dynamic(grid, caster.position, target, distance, mode)
        end

      combat_state
      |> CombatState.update_target(target, final_target)
      |> Map.put(:grid, final_grid)
    end

    def process(%Move{}, _target, %CombatState{} = combat_state), do: combat_state

    defp do_move_fixed(grid, _dir, target, 0), do: {target, grid}

    defp do_move_fixed(grid, {dq, dr, ds} = dir, target, steps) do
      {tq, tr, ts} = target.position
      next_pos = {tq + dq, tr + dr, ts + ds}

      if not Map.has_key?(grid.tiles, next_pos) or Grid.tile_blocked?(grid, next_pos) do
        {target, grid}
      else
        new_grid = Grid.update_position(grid, target, target.position, next_pos)
        new_target = Character.move(target, next_pos)
        do_move_fixed(new_grid, dir, new_target, steps - 1)
      end
    end

    defp do_move_dynamic(grid, _caster_pos, target, 0, _mode), do: {target, grid}

    defp do_move_dynamic(grid, caster_pos, target, steps, mode) do
      {dq, dr, ds} =
        case mode do
          :pull -> Grid.direction_toward(grid, target.position, caster_pos)
          :push -> Grid.direction_toward(grid, caster_pos, target.position)
        end

      {tq, tr, ts} = target.position
      next_pos = {tq + dq, tr + dr, ts + ds}

      if not Map.has_key?(grid.tiles, next_pos) or Grid.tile_blocked?(grid, next_pos) do
        {target, grid}
      else
        new_grid = Grid.update_position(grid, target, target.position, next_pos)
        new_target = Character.move(target, next_pos)
        do_move_dynamic(new_grid, caster_pos, new_target, steps - 1, mode)
      end
    end

    def get_description(%Move{angle: angle, distance: distance}) do
      "Move target #{distance} tile(s) in direction #{angle}"
    end

    def get_icon(%Move{}), do: "hero-arrows-pointing-out-solid"

    def get_value_label(%Move{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Move{distance: d}), do: "#{d}"

    def animate(%Move{}), do: %{label: "MOVE", color: :blue}

    def params(_), do: ["angle", "distance", "trajectory"]
  end
end
