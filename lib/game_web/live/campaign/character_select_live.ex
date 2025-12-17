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
       game_state: %{
         campaign: %{
           character: nil
         }
       }
     )}
  end

  @impl true
  def handle_event("select_character", %{"id" => id}, socket) do
    base_class = Content.get_base_class!(id) |> Game.Repo.preload(deck: [:cards])
    character = Character.from_character_data(base_class)

    game_state = %{
      campaign: %{
        character: character
      }
    }

    # Debug output to iex shell
    dbg(game_state)

    {:noreply, assign(socket, game_state: game_state)}
  end
end
