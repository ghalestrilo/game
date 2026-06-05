defmodule GameWeb.GameBoard do
  use Phoenix.LiveComponent
  import GameWeb.CoreComponents
  alias Game.Grid

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

    tile_classes_json = build_tile_classes_json(overlay, combat, assigns[:current_player])
    blast_map_json = encode_blast_map(blast_map)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:static_map, fn -> false end)
     |> assign_new(:context, fn -> :combat end)
     |> assign_new(:spawn_points, fn -> %{} end)
     |> assign(:tile_classes_json, tile_classes_json)
     |> assign(:blast_map_json, blast_map_json)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 flex items-center justify-center overflow-hidden">
      <% queue = Game.CombatState.get_current_queue(@game_state.combat) %>
      <% rows = Game.Grid.to_rows(@game_state.combat.grid) %>
      <% pos = build_position_index(rows) %>
      <% spawn_index = build_spawn_index(@spawn_points) %>
      <div
        id="game-board"
        class="game-board"
        phx-hook="BoardTileClasses"
        data-tile-classes={@tile_classes_json}
        data-blast-map={@blast_map_json}
      >
        <!-- Map layer -->
        <div id="map-layer" phx-update={if @static_map, do: "replace", else: "ignore"}>
          <%= for row <- rows do %>
            <div class="flex flex-row justify-center gap-2">
              <%= for {q, r, s, tile} <- row do %>
                <div
                  phx-click="interact"
                  phx-value-target_position={"#{q}_#{r}_#{s}"}
                  data-coord={"#{q}_#{r}_#{s}"}
                  class={[
                    "hex-cell border border-base-content/20 w-20 h-20 flex items-center justify-center bg-base-100",
                    wall_class(tile),
                    spawn_class({q, r, s}, spawn_index, @context),
                    terrain_class(tile, @context)
                  ]}
                >
                  <span
                    :if={@context == :edit}
                    class="text-[10px] font-bold select-none pointer-events-none text-base-content/60"
                  >
                    {Elixir.Map.get(spawn_index, {q, r, s})}
                  </span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Entity layer -->
        <div class="absolute inset-0 pointer-events-none">
          <%= for character <- queue, character != nil, visible_to?(character, @current_player) do %>
            <div
              id={"character-#{character.id}"}
              phx-key={to_string(character.id)}
              phx-hook="CharacterEffects"
              phx-click="interact"
              phx-value-target_character_id={character.id}
              class={[
                "character absolute top-0 left-0 pointer-events-auto cursor-pointer !bg-cover !bg-no-repeat",
                character_filter_class(character, @current_player)
              ]}
              data-character-id={character.id}
              style={character_style(pos, character)}
            >
              <div
                :if={Game.Character.get_status_effect(character, :shield) != nil}
                class="rounded-full absolute inset-0 bg-info/60 animate-pulse pointer-events-none"
              />
              <span class="indicator-item indicator-top indicator-center">
                <span
                  :for={effect <- character.status_effects}
                  class={["badge badge-sm rounded-full !p-0.5", Game.StatusEffect.badge_class(effect)]}
                >
                  <.icon name={Game.StatusEffect.icon_for(effect.type)} class="size-3" />
                </span>
              </span>
              <div class={[
                "badge !border-0 !mt-14 badge-sm text-base-content",
                if(same_team?(@current_player, character), do: "bg-red-800", else: "bg-green-800")
              ]}>
                {character.name}
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("interact", params, socket) do
    send(self(), {:parent_event, "interact", params})
    {:noreply, socket}
  end

  # Server-managed tile CSS classes. Each value is a list of individual class tokens
  # (no spaces) so classList.add(...tokens) works correctly in JS.
  # Keep in sync with SERVER_CLASSES in app.js.
  @overlay_classes %{
    valid: ~w(ring-2 ring-inset ring-error/20 bg-error/5),
    invalid: ~w(opacity-40)
  }
  @movement_class ~w(bg-warning/10)
  @player_pos_class ~w(!bg-success/30)

  defp build_tile_classes_json(overlay, combat, current_player) when not is_nil(combat) do
    queue = Game.CombatState.get_current_queue(combat)
    current_turn_visible = current_turn_visible?(combat, queue, current_player)

    all_coords = Map.keys(combat.grid.tiles)

    all_coords
    |> Enum.reduce(%{}, fn coord, acc ->
      classes =
        [
          Map.get(@overlay_classes, Map.get(overlay, coord)),
          if(current_turn_visible && within_movement_range?(combat, coord),
            do: @movement_class
          ),
          if(current_turn_visible && current_player_at?(combat, queue, coord),
            do: @player_pos_class
          )
        ]
        |> Enum.reject(&is_nil/1)
        |> List.flatten()

      if classes == [] do
        acc
      else
        Map.put(acc, encode_coord(coord), classes)
      end
    end)
    |> Jason.encode!()
  end

  defp build_tile_classes_json(_overlay, _combat, _current_player), do: "{}"

  defp encode_coord({q, r, s}), do: "#{q}_#{r}_#{s}"

  defp encode_blast_map(blast_map) do
    blast_map
    |> Map.new(fn {coord, blast_coords} ->
      {encode_coord(coord), Enum.map(blast_coords, &encode_coord/1)}
    end)
    |> Jason.encode!()
  end

  defp within_movement_range?(combat, coord) do
    player = Game.CombatState.get_current_player(combat)

    if player do
      turn = Game.CombatState.get_current_turn(combat)

      movement_remaining =
        turn[:movement_remaining] ||
          Game.Character.effective_attribute(player, "movement_range")

      Grid.distance(combat.grid, coord, player.position) <= movement_remaining
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

  defp build_position_index(rows) do
    cell = 80
    gap = 8
    step = cell + gap

    max_cols = rows |> Enum.map(&length/1) |> Enum.max()
    board_w = max_cols * cell + (max_cols - 1) * gap

    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, row_idx} ->
      n = length(row)
      row_w = n * cell + (n - 1) * gap
      x0 = (board_w - row_w) / 2

      row
      |> Enum.with_index()
      |> Enum.map(fn {{q, r, s, _}, col_idx} ->
        {{q, r, s}, {x0 + col_idx * step + cell / 2, row_idx * step + cell / 2}}
      end)
    end)
    |> Map.new()
  end

  defp character_style(pos, character) do
    background = "background: #{character_bg(character)};"
    padding = 20
    r = 32
    vertical_scaling = 0.92

    case Map.get(pos, character.position) do
      {left, top} ->
        background <>
          "translate: #{left - r + padding}px calc(#{vertical_scaling} * #{top - r + padding}px);"

      nil ->
        background <> "display: none;"
    end
  end

  defp character_bg(%{avatar_url: url}) when is_binary(url) and url != "",
    do: "url('#{url}')"

  defp character_bg(_), do: ""

  # Ethereal: fully desaturated for everyone — untargetable by design, clearly distinct.
  # Stealth (own team): gray + slightly dimmed so the player knows they're hidden.
  # Stealth visibility filtering (hiding from enemies) is handled separately by visible_to?/2.
  defp character_filter_class(character, current_player) do
    cond do
      Game.Character.get_status_effect(character, :ethereal) != nil ->
        "grayscale opacity-40"

      stealthy?(character) and current_player != nil ->
        "grayscale opacity-60"

      true ->
        nil
    end
  end

  defp stealthy?(character) do
    Game.Character.get_status_effect(character, :stealth) != nil
  end

  # A stealthy character is only visible to players on the same team.
  # nil current_player means single-player/campaign — show everyone.
  defp visible_to?(_character, nil), do: true

  defp visible_to?(character, current_player) do
    not stealthy?(character) or character.team == current_player.team
  end

  defp wall?(tile) do
    Enum.any?(tile[:objects] || [], fn obj -> match?(%Game.MapObject.Wall{}, obj) end)
  end

  defp wall_class(tile) do
    if wall?(tile), do: "!bg-amber-900/80 cursor-not-allowed", else: nil
  end

  # Returns a map of {q,r,s} => display label for each spawn point.
  defp build_spawn_index(spawn_points) do
    Elixir.Map.new(spawn_points, fn {team, coords} ->
      label =
        team
        |> to_string()
        |> String.replace("team_", "T")
        |> String.upcase()

      {coords, label}
    end)
  end

  defp spawn_class(coord, spawn_index, :edit) do
    if Elixir.Map.has_key?(spawn_index, coord),
      do: "!bg-info/20 ring-2 ring-inset ring-info/40",
      else: nil
  end

  defp spawn_class(_coord, _spawn_index, _context), do: nil

  defp terrain_class(%{terrain: nil}, :edit), do: "!opacity-30 !bg-base-300 !border-dashed"
  defp terrain_class(_tile, _context), do: nil

  def same_team?(%{team: team}, %{team: team}) when not is_nil(team), do: true
  def same_team?(_current_player, _character), do: false

  if Mix.env() == :test do
    def visible_to_for_test?(character, current_player),
      do: visible_to?(character, current_player)
  end
end
