defmodule GameWeb.CharacterLive.FormComponent do
  use GameWeb, :live_component

  alias Game.Data
  alias Game.BaseDecks.BaseDeck
  import GameWeb.CoreComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage character records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="character-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:class]} type="text" label="Class" />
        <.input field={@form[:base_hp]} type="number" label="Base hp" />
        <.input field={@form[:base_ap]} type="number" label="Base ap" />
        <.input field={@form[:base_movement]} type="number" label="Base movement" />
        <.input
          field={@form[:deck_id]}
          type="select"
          label="Base Deck"
          prompt="Select a deck"
          options={Enum.map(@decks, &{&1.name, &1.id})}
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save Character</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{character: character} = assigns, socket) do
    decks = Game.Repo.all(BaseDeck)
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:decks, decks)
     |> assign_new(:form, fn ->
       to_form(Data.change_character(character))
     end)}
  end

  @impl true
  def handle_event("validate", %{"character" => character_params}, socket) do
    changeset = Data.change_character(socket.assigns.character, character_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"character" => character_params}, socket) do
    save_character(socket, socket.assigns.action, character_params)
  end

  defp save_character(socket, :edit, character_params) do
    case Data.update_character(socket.assigns.character, character_params) do
      {:ok, character} ->
        notify_parent({:saved, character})

        {:noreply,
         socket
         |> put_flash(:info, "Character updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_character(socket, :new, character_params) do
    case Data.create_character(character_params) do
      {:ok, character} ->
        notify_parent({:saved, character})

        {:noreply,
         socket
         |> put_flash(:info, "Character created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
