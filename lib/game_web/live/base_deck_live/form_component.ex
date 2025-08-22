defmodule GameWeb.BaseDeckLive.FormComponent do
  use GameWeb, :live_component

  alias Game.BaseDecks

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage base_deck records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="base_deck-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Base deck</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{base_deck: base_deck} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(BaseDecks.change_base_deck(base_deck))
     end)}
  end

  @impl true
  def handle_event("validate", %{"base_deck" => base_deck_params}, socket) do
    changeset = BaseDecks.change_base_deck(socket.assigns.base_deck, base_deck_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"base_deck" => base_deck_params}, socket) do
    save_base_deck(socket, socket.assigns.action, base_deck_params)
  end

  defp save_base_deck(socket, :edit, base_deck_params) do
    case BaseDecks.update_base_deck(socket.assigns.base_deck, base_deck_params) do
      {:ok, base_deck} ->
        notify_parent({:saved, base_deck})

        {:noreply,
         socket
         |> put_flash(:info, "Base deck updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_base_deck(socket, :new, base_deck_params) do
    case BaseDecks.create_base_deck(base_deck_params) do
      {:ok, base_deck} ->
        notify_parent({:saved, base_deck})

        {:noreply,
         socket
         |> put_flash(:info, "Base deck created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
