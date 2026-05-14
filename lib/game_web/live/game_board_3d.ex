defmodule GameWeb.GameBoard3D do
  use Phoenix.LiveComponent

  @overlay_classes %{
    valid: "valid",
    invalid: "invalid"
  }
  @movement_class "movement"
  @player_pos_class "player"

  @impl true
  def update(assigns, socket) do
    card = get_in(assigns, [:game_state, :combat, :current_turn, :card])
    selecting_target = get_in(assigns, [:game_state, :combat, :state]) === :card_selected
    combat = get_in(assigns, [:game_state, :combat])

    {overlay, blast_map} =
      if card && combat && selecting_target do
        Game.Card.build_tile_overlay(card, combat)
      else
        {%{}, %{}}
      end

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:current_player, fn -> nil end)

    tiles = build_tiles(combat, overlay)
    characters = build_characters(combat, assigns[:current_player])
    encoded_blast_map = encode_blast_map(blast_map)

    socket =
      push_event(socket, "board_state", %{
        tiles: tiles,
        characters: characters,
        blast_map: encoded_blast_map
      })

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 relative overflow-hidden">
      <div
        id="game-board-3d"
        phx-hook="ThreeJSBoard"
        style="width: 100%; height: 100%;"
      >
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("interact", params, socket) do
    send(self(), {:parent_event, "interact", params})
    {:noreply, socket}
  end

  defp build_tiles(nil, _overlay), do: []

  defp build_tiles(combat, overlay) do
    queue = Game.CombatState.get_current_queue(combat)
    current_player = combat.current_turn.player

    combat.grid.tiles
    |> Enum.map(fn {{q, r, s}, tile} ->
      highlight =
        cond do
          Map.has_key?(overlay, {q, r, s}) ->
            Map.get(@overlay_classes, Map.get(overlay, {q, r, s}))

          current_player && within_movement_range?(combat, {q, r, s}) &&
              current_turn_visible?(combat, queue, current_player) ->
            @movement_class

          current_player_at?(combat, queue, {q, r, s}) &&
              current_turn_visible?(combat, queue, current_player) ->
            @player_pos_class

          true ->
            nil
        end

      %{
        q: q,
        r: r,
        s: s,
        has_object: wall?(tile),
        highlight: highlight
      }
    end)
  end

  defp build_characters(nil, _current_player), do: []

  defp build_characters(combat, current_player) do
    combat
    |> Game.CombatState.get_current_queue()
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&visible_to?(&1, current_player))
    |> Enum.map(fn character ->
      {q, r, s} = character.position

      %{
        id: character.id,
        q: q,
        r: r,
        s: s,
        team: to_string(character.team)
      }
    end)
  end

  defp encode_blast_map(blast_map) do
    Map.new(blast_map, fn {coord, blast_coords} ->
      {encode_coord(coord), Enum.map(blast_coords, &encode_coord/1)}
    end)
  end

  defp encode_coord({q, r, s}), do: "#{q}_#{r}_#{s}"

  defp wall?(tile) do
    Enum.any?(tile[:objects] || [], fn obj -> match?(%Game.MapObject.Wall{}, obj) end)
  end

  defp within_movement_range?(combat, coord) do
    player = Game.CombatState.get_current_player(combat)

    if player do
      turn = Game.CombatState.get_current_turn(combat)

      movement_remaining =
        turn[:movement_remaining] ||
          Game.Character.effective_attribute(player, "movement_range")

      Game.Grid.distance(combat.grid, coord, player.position) <= movement_remaining
    end
  end

  defp current_turn_visible?(combat, queue, current_player) do
    current_turn_character = Enum.find(queue, fn c -> c && c == combat.current_turn.player end)
    current_turn_character == nil or visible_to?(current_turn_character, current_player)
  end

  defp current_player_at?(combat, queue, coord) do
    combat.current_turn.player &&
      Enum.find(queue, fn c -> c && c.position == coord end) == combat.current_turn.player
  end

  defp visible_to?(_character, nil), do: true

  defp visible_to?(character, current_player) do
    stealthy = Game.Character.get_status_effect(character, :stealth) != nil
    not stealthy or character.team == current_player.team
  end
end
