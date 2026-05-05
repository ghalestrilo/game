defmodule Game.Combat.CardEffects.Move do
  alias Game.CombatState
  alias Game.{Character, Grid}

  @derive Jason.Encoder
  defstruct type: :move, value: {0, 0, 0}, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: {integer(), integer(), integer()} | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.Move

    def process(%Move{value: delta}, target, %CombatState{} = combat_state) do
      {dq, dr, ds} = to_delta(delta)
      {tq, tr, ts} = target.position
      new_pos = {tq + dq, tr + dr, ts + ds}

      if Map.has_key?(combat_state.grid.tiles, new_pos) and
           not Grid.tile_blocked?(combat_state.grid, new_pos) do
        updated_target = Character.move(target, new_pos)
        updated_grid = Grid.update_position(combat_state.grid, updated_target, target.position, new_pos)

        combat_state
        |> CombatState.update_target(target, updated_target)
        |> Map.put(:grid, updated_grid)
      else
        combat_state
      end
    end

    def get_description(%Move{value: delta}) do
      {dq, dr, ds} = to_delta(delta)
      "Push target by (#{dq}, #{dr}, #{ds})"
    end

    def get_icon(%Move{}), do: "hero-arrows-pointing-out-mini"

    def get_value_label(%Move{value_label: label}) when is_binary(label), do: label
    def get_value_label(%Move{value: delta}) do
      {dq, dr, ds} = to_delta(delta)
      "(#{dq},#{dr},#{ds})"
    end

    def animate(%Move{}), do: %{label: "PUSH", color: :blue}

    def params(_), do: ["q", "r", "s"]

    defp to_delta({dq, dr, ds}), do: {dq, dr, ds}
    defp to_delta(%{q: dq, r: dr, s: ds}), do: {dq, dr, ds}
    defp to_delta(%{"q" => dq, "r" => dr, "s" => ds}), do: {dq, dr, ds}
  end
end
