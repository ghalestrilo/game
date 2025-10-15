defmodule GameWeb.BaseCardLive.FormComponent do
  use GameWeb, :live_component

  alias Game.BaseCards

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage base_card records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="base_card-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <%!-- <.input field={@form[:effects]} type="select" multiple label="Effects" options={get_card_effects_as_options()} /> --%>
        <.input field={@form[:ap]} type="number" label="Ap" />
        <.input field={@form[:headline]} type="text" label="Headline" />
        <.input
          field={@form[:rarity]}
          type="select"
          label="Rarity"
          prompt="Choose a value"
          options={Ecto.Enum.values(Game.BaseCards.BaseCard, :rarity)}
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save Base card</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{base_card: base_card} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(BaseCards.change_base_card(base_card))
     end)}
  end

  @impl true
  def handle_event("validate", %{"base_card" => base_card_params}, socket) do
    changeset = BaseCards.change_base_card(socket.assigns.base_card, base_card_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"base_card" => base_card_params}, socket) do
    save_base_card(socket, socket.assigns.action, base_card_params)
  end

  defp save_base_card(socket, :edit, base_card_params) do
    case BaseCards.update_base_card(socket.assigns.base_card, base_card_params) do
      {:ok, base_card} ->
        notify_parent({:saved, base_card})

        {:noreply,
         socket
         |> put_flash(:info, "Base card updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_base_card(socket, :new, base_card_params) do
    case BaseCards.create_base_card(base_card_params) do
      {:ok, base_card} ->
        notify_parent({:saved, base_card})

        {:noreply,
         socket
         |> put_flash(:info, "Base card created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  # defp get_card_effects_as_options() do
  #   Game.BaseCards.list_basecards
  #   |> Enum.flat_map(& &1.effects)
  #   |> Enum.with_index()
  #   |> Enum.map(& {1, })
  # end

  # defp parse_effects(assigns, base_card_params) do
  #   Map.put(assigns.basecards, :effects, Enum.map(base_card_params["effects"], &Map.get(assigns.card_effects,&1)))
  # end
  # defp temp_format_effects_from_text(base_card_params) do
  #   case Jason.decode(base_card_params["effects"] || "") do
  #     {:ok, effects} -> Map.put(base_card_params, "effects", effects)
  #     _ -> base_card_params
  #   end
  # end
end
