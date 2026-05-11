defmodule GameWeb.GameLive do
  use GameWeb, :live_view
  import GameWeb.CombatActionHelpers

  alias Game.{Lobby, Character, Content}

  @move_directions %{
    "d" => {1, 0, -1},
    "a" => {-1, 0, 1},
    "z" => {-1, 1, 0},
    "e" => {1, -1, 0},
    "q" => {0, -1, 1},
    "c" => {0, 1, -1}
  }

  @impl true
  def mount(params, _session, socket) do
    mode = socket.assigns.live_action

    if connected?(socket) do
      mount_connected(mode, params, socket)
    else
      {:ok,
       assign(socket,
         lobby_id: nil,
         game_pid: nil,
         game_state: nil,
         current_player: nil,
         action_log: [],
         modal: nil,
         mode: mode,
         keyboard_target_index: 0
       )}
    end
  end

  defp mount_connected(:pvp, %{"id" => lobby_id}, socket) do
    user = socket.assigns.current_scope.user

    case Lobby.get(lobby_id) do
      {:error, :not_found} ->
        {:ok, push_navigate(socket, to: ~p"/mulztiplayer")}

      {:ok, %{game_pid: nil}} ->
        {:ok, push_navigate(socket, to: ~p"/multiplayer/#{lobby_id}")}

      {:ok, lobby} ->
        Lobby.subscribe(lobby_id)
        Game.subscribe(lobby.game_pid)

        current_player =
          lobby.players |> Enum.find(&(&1.id == user.id))

        {:ok,
         assign(socket,
           lobby_id: lobby_id,
           game_pid: lobby.game_pid,
           game_state: Game.get_state(lobby.game_pid),
           current_player: current_player,
           action_log: [],
           modal: nil,
           mode: :pvp,
           keyboard_target_index: 0
         )}
    end
  end

  defp mount_connected(:campaign, params, socket) do
    if is_nil(params["class"]) or params["class"] == "" do
      {:ok,
       socket
       |> put_flash(:error, "Please select a character first")
       |> push_navigate(to: ~p"/campaign/character-select")}
    else
      campaign = build_campaign(params)

      {:ok, lobby_id} =
        Lobby.create_single_player(:campaign, %{
          combatants: campaign_combatants(campaign),
          extra_state: %{campaign: campaign}
        })

      {:ok, lobby} = Lobby.get(lobby_id)
      Game.subscribe(lobby.game_pid)

      {:ok,
       assign(socket,
         lobby_id: lobby_id,
         game_pid: lobby.game_pid,
         game_state: Game.get_state(lobby.game_pid),
         current_player: nil,
         action_log: [],
         modal: nil,
         mode: :campaign,
         keyboard_target_index: 0
       )}
    end
  end

  defp mount_connected(:sandbox, params, socket) do
    combatants =
      parse_characters(params["characters"]) ||
        parse_initial_state(params["initial_state"])

    map_slug = params["map"]

    {:ok, lobby_id} =
      Lobby.create_single_player(:sandbox, %{combatants: combatants, map: map_slug})

    {:ok, lobby} = Lobby.get(lobby_id)
    Game.subscribe(lobby.game_pid)

    {:ok,
     assign(socket,
       lobby_id: lobby_id,
       game_pid: lobby.game_pid,
       game_state: Game.get_state(lobby.game_pid),
       current_player: nil,
       action_log: [],
       modal: nil,
       mode: :sandbox,
       keyboard_target_index: 0
     )}
  end

  # ---- handle_info ----

  @impl true
  def handle_info({:game_updated, game_state, animations}, socket) do
    socket =
      socket
      |> assign(game_state: game_state, action_log: Map.get(game_state, :action_log, []))
      |> push_animations(animations)
      |> checkpoint_if_single_player(game_state)

    if socket.assigns.mode == :pvp and game_state.combat.state == :game_over do
      Lobby.reset(socket.assigns.lobby_id)
    end

    {:noreply, socket}
  end

  # PvP teardown: game ended, lobby reset → navigate back to lobby
  def handle_info({:lobby_updated, %{game_pid: nil}}, %{assigns: %{mode: :pvp}} = socket) do
    {:noreply, push_navigate(socket, to: ~p"/multiplayer/#{socket.assigns.lobby_id}")}
  end

  def handle_info({:lobby_updated, _lobby}, socket), do: {:noreply, socket}

  def handle_info({:parent_event, event_name, params}, socket) do
    handle_event(event_name, params, socket)
  end

  # ---- handle_event ----

  @impl true
  def handle_event("pick_card", params, socket) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      combat = socket.assigns.game_state.combat
      player = combat.current_turn.player
      card = Enum.at(player.cards.hand, String.to_integer(params["card_index"]))
      action = "#{player.name} selected card: #{card.name}"

      Game.process_action(socket.assigns.game_pid, {:pick_card, player, card})

      {:noreply, socket |> assign(keyboard_target_index: 0)}
    end
  end

  # In your LiveView module
  def handle_event("handle_keys", %{"key" => number}, socket)
      when number in ~w(1 2 3 4 5 6 7 8 9) do
    current_player_hand_size =
      Enum.count(socket.assigns.game_state.combat.current_turn.player.cards.hand)

    handle_event(
      "pick_card",
      %{"card_index" => to_string(min(String.to_integer(number), current_player_hand_size) - 1)},
      socket
    )

    {:noreply, socket |> assign(keyboard_index_target: 0)}
  end

  def handle_event("handle_keys", %{"key" => "Enter"}, socket) do
    handle_event("skip_turn", %{}, socket)
    {:noreply, socket}
  end

  def handle_event(
        "handle_keys",
        %{"key" => key},
        %{assigns: %{game_state: %{combat: %{state: :card_selected} = combat}}} = socket
      )
      when key in ["s", "w"] do
    targets = keyboard_targets(combat)
    count = length(targets)

    if count == 0 do
      {:noreply, socket}
    else
      delta = if key == "s", do: 1, else: -1
      new_index = rem(socket.assigns.keyboard_target_index + delta + count, count)
      {_queue_index, target} = Enum.at(targets, new_index)

      socket =
        socket
        |> assign(keyboard_target_index: new_index)
        |> push_event("highlight-tile", %{coord: encode_coord(target.position)})

      {:noreply, socket}
    end
  end

  def handle_event(
        "handle_keys",
        %{"key" => " "},
        %{assigns: %{game_state: %{combat: %{state: :card_selected} = combat}}} = socket
      ) do
    targets = keyboard_targets(combat)
    result = Enum.at(targets, socket.assigns.keyboard_target_index)

    if result do
      {_queue_index, target} = result
      handle_event("interact", %{"target_character_id" => to_string(target.id)}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "handle_keys",
        %{"key" => key},
        %{assigns: %{game_state: %{combat: %{state: :running} = combat}}} = socket
      )
      when is_map_key(@move_directions, key) do
    {dq, dr, ds} = @move_directions[key]
    {q, r, s} = combat.current_turn.player.position
    target = "#{q + dq}_#{r + dr}_#{s + ds}"
    handle_event("interact", %{"target_position" => target}, socket)
  end

  def handle_event("handle_keys", %{"key" => key}, socket) do
    # IO.inspect(key <> " pressed")
    # Ignore other keys
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_character_id" => character_id},
        %{assigns: %{game_state: %{combat: %{state: :card_selected} = combat}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      character =
        Game.CombatState.get_current_queue(combat)
        |> Enum.find(&(to_string(&1.id) == character_id))

      if character do
        card = combat.current_turn.card
        action = "#{combat.current_turn.player.name} played card: #{card.name}"
        Game.process_action(socket.assigns.game_pid, {:play_card_on_character, character}, action)
        {:noreply, socket}
      else
        {:noreply, put_flash(socket, :error, "Target not found")}
      end
    end
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{assigns: %{game_state: %{combat: %{state: :card_selected} = combat}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      with {:ok, position} <- parse_hex_position(target_position) do
        card = combat.current_turn.card
        action = "#{combat.current_turn.player.name} played card: #{card.name}"
        Game.process_action(socket.assigns.game_pid, {:play_card, position}, action)
        {:noreply, socket}
      else
        {:error, reason} -> {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{assigns: %{game_state: %{combat: %{state: :running} = combat}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      with {:ok, position} <- parse_hex_position(target_position) do
        player = combat.current_turn.player
        action = "#{player.name} moved to position #{inspect(position)}"
        Game.process_action(socket.assigns.game_pid, {:move, player, position}, action)
        {:noreply, socket}
      else
        {:error, reason} -> {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_event("interact", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "skip_turn",
        _params,
        %{assigns: %{game_state: %{combat: %{current_turn: %{player: player}}}}} = socket
      ) do
    if not my_turn?(socket) do
      {:noreply, put_flash(socket, :error, "It's not your turn")}
    else
      action = "#{player.name} skipped their turn"
      Game.process_action(socket.assigns.game_pid, {:skip_turn, player}, action)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("win_match", _params, socket) do
    current_player = socket.assigns.game_state.combat.current_turn.player

    if is_nil(current_player) do
      {:noreply, put_flash(socket, :error, "No active player")}
    else
      updated_combat = force_game_over(socket.assigns.game_state.combat, current_player.team)
      new_state = %{socket.assigns.game_state | combat: updated_combat}

      :ok = GenServer.call(socket.assigns.game_pid, {:set_state, new_state})

      if socket.assigns.mode == :pvp do
        Lobby.reset(socket.assigns.lobby_id)
      end

      action = "#{current_player.name}'s team (#{current_player.team}) wins the match!"

      {:noreply,
       socket
       |> assign(game_state: new_state)
       |> update(:action_log, &Enum.slice([action | &1], 0, 20))}
    end
  end

  @impl true
  def handle_event("pick_booster_card", %{"card_index" => idx}, socket) do
    player_id =
      if socket.assigns.current_player,
        do: socket.assigns.current_player.id,
        else: socket.assigns.game_state.combat.current_turn.player.id

    my_booster = get_in(socket.assigns.game_state, [:booster_state, player_id])
    card = my_booster && Enum.at(my_booster.cards, String.to_integer(idx))

    if card do
      {:ok, new_state} = Game.pick_booster_card(socket.assigns.game_pid, player_id, card)
      {:noreply, assign(socket, game_state: new_state)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("enter_shop", _params, socket) do
    if socket.assigns.game_state.combat.state == :game_over do
      case Game.enter_shop(socket.assigns.game_pid) do
        {:ok, updated_state} ->
          updated_state = Map.put(updated_state, :current_view, :shop)

          {:noreply,
           socket
           |> assign(game_state: updated_state, modal: nil)
           |> put_flash(:info, "Welcome to the shop!")}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to enter shop: #{reason}")
           |> assign(modal: nil)}
      end
    else
      {:noreply, put_flash(socket, :error, "Combat must be over to enter shop")}
    end
  end

  @impl true
  def handle_event("select_shop_card", params, socket) do
    card_index = String.to_integer(params["card_index"])
    selected_card = Enum.at(socket.assigns.game_state.combat.shop_cards, card_index)
    campaign = socket.assigns.game_state.campaign
    character = campaign.character
    new_card = %{selected_card | id: length(character.cards.draw)}

    updated_character = %{
      character
      | cards: %{character.cards | draw: [new_card | character.cards.draw]}
    }

    updated_campaign = %{campaign | character: updated_character}
    new_game_state = restart_campaign_combat(socket.assigns.game_state, updated_campaign)
    :ok = GenServer.call(socket.assigns.game_pid, {:set_state, new_game_state})

    {:noreply,
     socket
     |> assign(game_state: new_game_state, action_log: [])
     |> put_flash(:info, "Card added to deck! Starting new combat...")}
  end

  @impl true
  def handle_event("help", params, socket) do
    {:noreply,
     socket
     |> assign(modal: :help)
    }
  end

  @impl true
  def handle_event("clear_modal", params, socket) do
    {:noreply,
     socket
     |> assign(modal: :nil)
    }
  end

  # ---- render ----

  @impl true
  def render(assigns) do
    ~H"""
    <div class="campaign-play" phx-window-keydown="handle_keys">
      <%= if @game_state && Map.get(@game_state, :current_view) == :booster do %>
        <% my_booster =
          Map.get(@game_state.booster_state || %{}, @current_player && @current_player.id) %>
        <div class="flex items-center justify-center h-screen">
          <.card_modal
            id="booster-modal"
            show={true}
            title="Booster Pack"
            subtitle={"Pick a card to add to your deck — #{my_booster && my_booster.remaining || 0} pack(s) remaining"}
            cards={(my_booster && my_booster.cards) || []}
            selectable={true}
            on_select="pick_booster_card"
          >
            <div
              :if={my_booster.remaining == 0}
              class="flex flex-col gap-4 items-center justify-center"
            >
              Waiting for other players <span class="loading loading-spinner loading-xl" />
            </div>
          </.card_modal>
        </div>
      <% end %>

      <%= if @game_state && Map.get(@game_state, :current_view) == :combat do %>
        <.live_component
          module={GameWeb.CombatLive}
          id="combat"
          game_state={@game_state}
          action_log={@action_log}
          modal={@modal}
          current_player={@current_player}
        />
      <% end %>

      <%= if @game_state && Map.get(@game_state, :current_view) == :shop do %>
        <.live_component module={GameWeb.ShopLive} id="shop" game_state={@game_state} />
      <% end %>

      <%= if is_nil(@game_state) || is_nil(Map.get(@game_state, :current_view)) do %>
        <div class="flex items-center justify-center h-screen">
          <p class="text-xl">Loading...</p>
        </div>
      <% end %>
      <.modal
        :if={@modal == :help}
        id="help-modal"
        show={true}
        on_cancel={JS.push("clear_modal")}
        >
        <h1 class="text-xl font-bold">Controls</h1>
        <h2 class="text-lg">Mouse</h2>
        <p>Clique numa carta, clique em onde jogar ela, depois aperte "Skip Turn" pra passar</p>

        <h2 class="text-lg">Keyboard (experimental)</h2>
        <ul>
          <li class="ml-2">Movimento no tabuleiro: teclas <b>q a z</b> / <b>e d c</b></li>
          <li class="ml-2"><b>"1-9"</b> para selecionar/deselecionar cartas</li>
          <li class="ml-2"><b>w</b> e <b>s</b> para escolher entre os alvos disponíveis</li>
          <li class="ml-2"><b>Barra de espaço</b> para jogar a carta selecionada carta</li>
          <li class="ml-2"><b>Enter</b> para passar o turno</li>
        </ul>
      </.modal>
    </div>
    """
  end

  # ---- private helpers ----

  defp checkpoint_if_single_player(%{assigns: %{mode: mode}} = socket, game_state)
       when mode in [:campaign, :sandbox] do
    checkpoint_combat(socket.assigns.lobby_id, game_state.combat)
    socket
  end

  defp checkpoint_if_single_player(socket, _game_state), do: socket

  defp build_campaign(params) do
    class = params["class"] || "ranger"
    player_name = params["player_name"] || "Hero"
    base_class = Content.get_base_class_by_class!(class)
    character = Character.from_character_data(base_class)
    %{character: character, player: %{name: player_name}}
  end

  defp campaign_combatants(campaign) do
    [
      %{character: campaign.character, team: 1, position: {0, 0, 0}, id: 0},
      %{class: "wolf", team: 2, position: {2, -1, -1}, id: 1}
    ]
  end

  defp restart_campaign_combat(game_state, updated_campaign) do
    combat = Game.CombatBuilder.build(campaign_combatants(updated_campaign))

    %{game_state | current_view: :combat, combat: combat, campaign: updated_campaign}
  end

  defp parse_characters(nil), do: nil

  defp parse_characters(encoded) do
    encoded
    |> String.split(",")
    |> Enum.with_index()
    |> Enum.map(fn {class, idx} ->
      %{class: String.trim(class), team: rem(idx, 2) + 1, id: idx}
    end)
  end

  defp parse_initial_state(nil), do: default_sandbox_combatants()

  defp parse_initial_state(encoded) do
    encoded
    |> String.trim_leading("[")
    |> String.trim_trailing("]")
    |> String.split(",")
    |> Enum.with_index()
    |> Enum.map(fn {entry, idx} ->
      case String.split(entry, ":") do
        [position, class, team] ->
          %{
            position: parse_position(position),
            class: class,
            team: String.to_integer(team),
            id: idx
          }

        _ ->
          raise "Invalid format for initial_state entry: #{entry}"
      end
    end)
  rescue
    _ -> default_sandbox_combatants()
  end

  defp default_sandbox_combatants do
    [
      %{class: "fighter", team: 1, position: {0, 0, 0}, id: 0},
      %{class: "ranger", team: 2, position: {2, -1, -1}, id: 1}
    ]
  end

  defp parse_position(str) do
    str |> String.split("_") |> Enum.map(&String.to_integer/1) |> List.to_tuple()
  end

  defp encode_coord({q, r, s}), do: "#{q}_#{r}_#{s}"

  defp keyboard_targets(combat) do
    card = combat.current_turn.card
    {overlay, _} = Game.Card.build_tile_overlay(card, combat)

    valid_coords =
      overlay |> Enum.filter(&match?({_, :valid}, &1)) |> MapSet.new(fn {coord, _} -> coord end)

    Game.CombatState.get_current_queue(combat)
    |> Enum.with_index()
    |> Enum.filter(fn {character, _i} -> MapSet.member?(valid_coords, character.position) end)
    |> Enum.map(fn {character, i} -> {i, character} end)
  end
end
