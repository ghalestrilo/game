defmodule GameWeb.Campaign.CharacterSelectLive do
  use GameWeb, :live_view
  alias Game.Content
  alias Game.Character

  @impl true
  def mount(_params, _session, socket) do
    base_classes = Content.list_base_classes()

    {:ok,
     assign(socket,
       base_classes: base_classes,
       campaign: %{
         character: nil,
         player: %{
           name: ""
         }
       }
     )}
  end

  @impl true
  def handle_event("update_player_name", params, socket) do
    name = params["player_name"] || params["value"] || ""
    campaign = socket.assigns.campaign
    updated_campaign = put_in(campaign[:player][:name], name)

    {:noreply, assign(socket, campaign: updated_campaign)}
  end

  @impl true
  def handle_event("select_character", %{"id" => id}, socket) do
    base_class = Content.get_base_class!(id) |> Game.Repo.preload(deck: [:cards])
    character = Character.from_character_data(base_class)

    campaign = socket.assigns.campaign
    updated_campaign = put_in(campaign[:character], character)

    # Debug output to iex shell
    dbg(updated_campaign)

    {:noreply, assign(socket, campaign: updated_campaign)}
  end
end
