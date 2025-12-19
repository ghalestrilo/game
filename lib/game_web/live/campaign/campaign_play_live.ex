defmodule GameWeb.Campaign.CampaignPlayLive do
  use GameWeb, :live_view
  alias Game
  alias Game.Combat
  alias Game.Character
  alias Game.Content

  @impl true
  def mount(params, _session, socket) do
    # Guard: Redirect if required params are missing
    if is_nil(params["class"]) or params["class"] == "" do
      {:ok,
       socket
       |> put_flash(:error, "Please select a character first")
       |> push_navigate(to: ~p"/campaign/character-select")}
    else
      if connected?(socket) do
        # Get campaign state from params or create test campaign
        campaign = create_campaign_from_params(params)

        # Initialize combat from campaign
        combat_state = initialize_combat_from_campaign(campaign)

        game_state = %{
          current_view: :combat,
          campaign: campaign,
          combat: combat_state
        }

        # Start game GenServer
        {:ok, game_pid} = Game.start_link()
        :ok = GenServer.call(game_pid, {:set_state, game_state})

        {:ok,
         assign(socket,
           game_pid: game_pid,
           game_state: game_state,
           action_log: [],
           modal: nil
         )}
      else
        {:ok, assign(socket, game_pid: nil, game_state: nil, action_log: [], modal: nil)}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="campaign-play">
      <%= if @game_state && Map.get(@game_state, :current_view) == :combat do %>
        <.live_component
          module={GameWeb.CombatLive}
          id="combat"
          game_state={@game_state}
          action_log={@action_log}
          modal={@modal}
        />
      <% end %>

      <%= if @game_state && Map.get(@game_state, :current_view) == :shop do %>
        <.live_component module={GameWeb.ShopLive} id="shop" game_state={@game_state} />
      <% end %>

      <%= if is_nil(@game_state) || is_nil(Map.get(@game_state, :current_view)) do %>
        <div class="flex items-center justify-center h-screen">
          <div class="text-center">
            <p class="text-xl mb-4">Loading campaign...</p>
            <p class="text-sm text-gray-600">
              If this persists, please return to character selection.
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Event handlers - similar to GameLive
  @impl true
  def handle_event("reset", _params, socket) do
    campaign = socket.assigns.game_state.campaign
    combat_state = initialize_combat_from_campaign(campaign)

    game_state = %{
      current_view: :combat,
      campaign: campaign,
      combat: combat_state
    }

    :ok = GenServer.call(socket.assigns.game_pid, {:set_state, game_state})

    {:noreply,
     assign(socket,
       game_state: game_state,
       action_log: []
     )}
  end

  @impl true
  def handle_event("pick_card", params, socket) do
    current_turn = socket.assigns.game_state.combat.current_turn
    card = current_turn.player.cards.hand |> Enum.at(String.to_integer(params["card_index"]))

    combat =
      with {:ok, updated_combat} <-
             process_game_action(socket, {:pick_card, current_turn.player, card}) do
        updated_combat
      else
        {:error, _error} ->
          socket.assigns.game_state.combat
      end

    action = "#{current_turn.player.name} selected card: #{card.name}"
    updated_log = [action | socket.assigns.action_log]
    updated_game_state = %{socket.assigns.game_state | combat: combat}

    # Sync GenServer state if combat ended
    sync_game_state_if_needed(socket.assigns.game_pid, updated_game_state)

    {:noreply,
     assign(socket,
       game_state: updated_game_state,
       action_log: updated_log
     )}
  end

  @impl true
  def handle_event(
        "interact",
        params,
        %{
          assigns: %{game_state: %{combat: %{state: :card_selected, current_turn: %{card: card}}}}
        } = socket
      ) do
    with {:ok, position} <- parse_target_position(params["target_position"]),
         {:ok, combat} <- process_game_action(socket, {:play_card, position}) do
      action =
        "#{socket.assigns.game_state.combat.current_turn.player.name} played card: #{card.name}"

      updated_log = [action | socket.assigns.action_log]
      updated_game_state = %{socket.assigns.game_state | combat: combat}

      # Sync GenServer state if combat ended
      sync_game_state_if_needed(socket.assigns.game_pid, updated_game_state)

      {:noreply,
       assign(socket,
         game_state: updated_game_state,
         action_log: updated_log
       )}
    else
      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, "#{error}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "interact",
        %{"target_position" => target_position},
        %{
          assigns: %{game_state: %{combat: %{state: :running, current_turn: %{player: player}}}}
        } = socket
      ) do
    {:ok, position} = parse_target_position(target_position)

    with {:ok, combat} <- process_game_action(socket, {:move, player, position}) do
      action = "#{player.name} moved to position #{inspect(position)}"
      updated_log = [action | socket.assigns.action_log]
      updated_game_state = %{socket.assigns.game_state | combat: combat}

      # Sync GenServer state if combat ended
      sync_game_state_if_needed(socket.assigns.game_pid, updated_game_state)

      {:noreply,
       assign(socket,
         game_state: updated_game_state,
         action_log: updated_log
       )}
    else
      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, "#{error}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("interact", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "skip_turn",
        _params,
        %{
          assigns: %{game_state: %{combat: %{current_turn: %{player: player}}}}
        } = socket
      ) do
    with {:ok, combat} <- process_game_action(socket, {:skip_turn, player}) do
      action = "#{player.name} skipped their turn"
      updated_log = [action | socket.assigns.action_log]
      updated_game_state = %{socket.assigns.game_state | combat: combat}

      # Sync GenServer state if combat ended
      sync_game_state_if_needed(socket.assigns.game_pid, updated_game_state)

      {:noreply,
       assign(socket,
         game_state: updated_game_state,
         action_log: updated_log
       )}
    else
      {:error, error} ->
        socket =
          socket
          |> put_flash(:error, "#{error}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("win_match", _params, socket) do
    if socket.assigns.game_state.combat.current_turn.player do
      current_player = socket.assigns.game_state.combat.current_turn.player
      winning_team = current_player.team

      updated_queue =
        Enum.map(socket.assigns.game_state.combat.queue, fn char ->
          if char.team != winning_team do
            %{char | dead: true, hp: 0}
          else
            char
          end
        end)

      updated_current_player =
        if current_player.team != winning_team do
          %{current_player | dead: true, hp: 0}
        else
          current_player
        end

      updated_combat = %{
        socket.assigns.game_state.combat
        | state: :game_over,
          queue: updated_queue,
          current_turn: %{
            socket.assigns.game_state.combat.current_turn
            | player: updated_current_player
          }
      }

      updated_game_state = %{socket.assigns.game_state | combat: updated_combat}

      if socket.assigns.game_pid do
        :ok = GenServer.call(socket.assigns.game_pid, {:set_state, updated_game_state})
      end

      action = "#{current_player.name}'s team (#{winning_team}) wins the match!"
      updated_log = [action | socket.assigns.action_log]

      {:noreply,
       assign(socket,
         game_state: updated_game_state,
         action_log: updated_log
       )}
    else
      {:noreply, put_flash(socket, :error, "No active player")}
    end
  end

  @impl true
  def handle_event("enter_shop", _params, socket) do
    if socket.assigns.game_state.combat.state == :game_over && socket.assigns.game_pid do
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
    # Get the selected card from shop
    card_index = String.to_integer(params["card_index"])
    selected_card = Enum.at(socket.assigns.game_state.combat.shop_cards, card_index)

    # Get the campaign state and add the selected card to the character's deck
    campaign = socket.assigns.game_state.campaign

    # Add the selected card to the character's draw pile (deck)
    character = campaign.character
    new_card_id = length(character.cards.draw)
    new_card = %{selected_card | id: new_card_id}

    updated_character = %{
      character
      | cards: %{character.cards | draw: [new_card | character.cards.draw]}
    }

    # Update the campaign with the modified character
    updated_campaign = %{campaign | character: updated_character}

    # Reinitialize combat based on the updated campaign state
    combat_state = initialize_combat_from_campaign(updated_campaign)

    updated_game_state = %{
      socket.assigns.game_state
      | current_view: :combat,
        combat: combat_state,
        campaign: updated_campaign
    }

    # Update the GenServer state
    if socket.assigns.game_pid do
      :ok = GenServer.call(socket.assigns.game_pid, {:set_state, updated_game_state})
    end

    {:noreply,
     socket
     |> assign(game_state: updated_game_state, action_log: [])
     |> put_flash(:info, "Card added to deck! Starting new combat...")}
  end

  @impl true
  def handle_info({:parent_event, event_name, params}, socket) do
    handle_event(event_name, params, socket)
  end

  # Helper functions
  defp create_campaign_from_params(params) do
    # Get character class from params, default to ranger if not provided
    character_class = params["class"] || "ranger"
    player_name = params["player_name"] || "Hero"

    # Load the character from database
    base_class = Content.get_base_class_by_class!(character_class)
    player_character = Character.from_character_data(base_class)

    %{
      character: player_character,
      player: %{
        name: player_name
      }
    }
  end

  defp initialize_combat_from_campaign(campaign) do
    # Use the campaign character (with its updated deck) and reset HP/AP
    char = campaign.character

    player_character =
      char
      |> Map.put(:hp, Character.get_max_hp(char))
      |> Map.put(:ap, Character.get_max_ap(char))
      |> Map.put(:position, {0, 0, 0})
      |> Map.put(:team, 1)
      |> Map.put(:id, 0)
      |> Map.put(:dead, false)
      # Reset card piles but keep the deck (draw pile)
      |> Map.update!(:cards, fn cards ->
        %{
          draw: Enum.shuffle(cards.draw),
          hand: [],
          discard: []
        }
      end)
      |> Character.draw_cards(5)

    # Create wolf enemy from database
    wolf_character =
      :wolf
      |> to_string()
      |> Content.get_base_class_by_class!()
      |> Character.from_character_data()
      |> Character.shuffle_deck()
      |> Map.put(:position, {2, -1, -1})
      |> Map.put(:team, 2)
      |> Map.put(:id, 1)
      |> Character.draw_cards(5)

    characters = [player_character, wolf_character]

    # Create grid
    positions = [{0, 0, 0}, {2, -1, -1}]

    max_radius =
      positions
      |> Enum.map(&Game.Grid.normalize/1)
      |> Enum.map(fn {q, r, s} -> div(abs(q) + abs(r) + abs(s), 2) end)
      |> Enum.max()

    padded_radius = max_radius + 1
    grid = Game.Grid.new({padded_radius, padded_radius, padded_radius})

    # Update the grid with the characters
    grid = Enum.reduce(characters, grid, &Game.Grid.update_character(&2, &1))

    # Create combat struct
    shop_cards = generate_shop_cards(4)

    %Game.CombatState{
      state: :running,
      __constants__: %{players: characters},
      queue: characters,
      grid: grid,
      shop_cards: shop_cards
    }
    |> Game.CombatState.initialize_queue()
    |> Game.CombatState.setup_player_turn()
  end

  # Helper function to generate random shop cards
  defp generate_shop_cards(count) do
    all_cards = [
      Game.Fixtures.attack_card(),
      Game.Fixtures.heal_card(),
      Game.Fixtures.fireball_card(),
      Game.Fixtures.expensive_card()
    ]

    all_cards
    |> Enum.take(count)
    |> Enum.with_index()
    |> Enum.map(fn {card, idx} -> %{card | id: idx + 1000} end)
  end

  defp process_game_action(socket, action) do
    with {:ok, updated_combat} <-
           Combat.process_action(
             socket.assigns.game_state.combat,
             action
           ) do
      {:ok, updated_combat}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_target_position(target_position) do
    with [q, r, s] <-
           target_position
           |> String.split("_")
           |> Enum.map(&String.to_integer/1) do
      {:ok, {q, r, s}}
    else
      _ -> {:error, "Invalid target position"}
    end
  end

  # Syncs the GenServer state when combat ends to ensure shop entry works correctly
  defp sync_game_state_if_needed(game_pid, game_state) do
    if game_pid && game_state.combat.state == :game_over do
      :ok = GenServer.call(game_pid, {:set_state, game_state})
    end
  end
end
