defmodule GameWeb.BaseClassLive.FormComponent do
  use GameWeb, :live_component

  alias Game.Content
  alias Game.BaseDecks.BaseDeck
  import GameWeb.CoreComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage base_class records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="base_class-form"
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
          <.button phx-disable-with="Saving...">Save Base Class</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{base_class: base_class} = assigns, socket) do
    decks = Game.Repo.all(BaseDeck)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:decks, decks)
     |> assign_new(:form, fn ->
       to_form(Content.change_base_class(base_class))
     end)}
  end

  @impl true
  def handle_event("validate", %{"base_class" => base_class_params}, socket) do
    changeset = Content.change_base_class(socket.assigns.base_class, base_class_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"base_class" => base_class_params}, socket) do
    save_base_class(socket, socket.assigns.action, base_class_params)
  end

  defp save_base_class(socket, :edit, base_class_params) do
    case Content.update_base_class(socket.assigns.base_class, base_class_params) do
      {:ok, base_class} ->
        notify_parent({:saved, base_class})

        {:noreply,
         socket
         |> put_flash(:info, "Base Class updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_base_class(socket, :new, base_class_params) do
    case Content.create_base_class(base_class_params) do
      {:ok, base_class} ->
        notify_parent({:saved, base_class})

        {:noreply,
         socket
         |> put_flash(:info, "Base Class created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
