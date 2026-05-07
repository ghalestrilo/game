defmodule Game.CombatBuilder do
  alias Game.{Character, Content, CombatState, Grid}

  @default_grid_padding 4

  @doc """
  Builds a CombatState from a list of player descriptors.

  Each player descriptor is a map with:
    - :class     — string class name (looked up from DB)
    - :team      — integer team number
    - :position  — {q, r, s} tuple
    - :id        — integer character id
    - :character — optional pre-built Character struct (skips DB lookup if present)
  """
  def build(player_specs) do
    characters =
      player_specs
      |> Enum.map(&build_character/1)
      |> Enum.map(&Character.draw_cards(&1, 5))

    positions = Enum.map(characters, & &1.position)

    max_radius =
      positions
      |> Enum.map(&Grid.normalize/1)
      |> Enum.map(fn {q, r, s} -> div(abs(q) + abs(r) + abs(s), 2) end)
      |> Enum.max()

    grid =
      Grid.new({max_radius + @default_grid_padding, max_radius + @default_grid_padding, max_radius + @default_grid_padding})
      |> then(fn g -> Enum.reduce(characters, g, &Grid.update_character(&2, &1)) end)

    %CombatState{
      state: :running,
      __constants__: %{players: characters},
      queue: characters,
      grid: grid,
      shop_cards: []
    }
    |> CombatState.initialize_queue()
    |> CombatState.setup_player_turn()
  end

  defp build_character(%{character: char, team: team, position: position, id: id}) do
    char
    |> Map.put(:hp, Character.get_max_hp(char))
    |> Map.put(:ap, Character.get_max_ap(char))
    |> Map.put(:position, position)
    |> Map.put(:team, team)
    |> Map.put(:id, id)
    |> Map.put(:dead, false)
    |> Map.update!(:cards, fn cards ->
      %{draw: Enum.shuffle(cards.draw), hand: [], discard: []}
    end)
  end

  defp build_character(%{class: class, team: team, position: position, id: id}) do
    class
    |> to_string()
    |> Content.get_base_class_by_class!()
    |> Character.from_character_data()
    |> Character.shuffle_deck()
    |> Map.put(:position, position)
    |> Map.put(:team, team)
    |> Map.put(:id, id)
    |> Map.put(:dead, false)
  end
end
