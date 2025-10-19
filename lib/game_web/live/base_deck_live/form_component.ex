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
        <div id="base_deck_cards-list" class="flex gap-2 flex-col items-baseline">
          <label>Cards in Deck</label>
          <%= for {base_deck_card, idx} <- Enum.with_index(@form.params["base_deck_cards"] || @form[:base_deck_cards].value || []) do %>
            <% base_deck_card =
              if is_tuple(base_deck_card), do: elem(base_deck_card, 1), else: base_deck_card %>
            <% card_id = Map.get(base_deck_card, "card_id") || Map.get(base_deck_card, :card_id) %>
            <% count = Map.get(base_deck_card, "count") || Map.get(base_deck_card, :count) %>
            <% id = Map.get(base_deck_card, "id") || Map.get(base_deck_card, :id) %>
            <div
              class="flex w-full gap-4 items-end justify-between [&_div]:w-full"
              id={"base_deck_card-#{idx}"}
            >
              <input type="hidden" name={"#{@form.name}[base_deck_cards][#{idx}][id]"} value={id} />
              <.input
                class="flex-1 w-full"
                name={"#{@form.name}[base_deck_cards][#{idx}][card_id]"}
                id={"#{@form.id}_base_deck_cards_#{idx}_card_id"}
                value={card_id}
                type="select"
                label="Card"
                options={for card <- @cards, do: {card.name, card.id}}
              />
              <.input
                class="flex-1 w-full"
                name={"#{@form.name}[base_deck_cards][#{idx}][count]"}
                id={"#{@form.id}_base_deck_cards_#{idx}_count"}
                value={count}
                type="number"
                label="Count"
              />
              <button
                type="button"
                class="my-[10px]"
                phx-click="remove_base_deck_card"
                phx-value-idx={idx}
                phx-target={@myself}
              >
                ✕
              </button>
            </div>
          <% end %>
          <button
            type="button"
            class="rounded bg-gray-100 p-2"
            phx-click="add_base_deck_card"
            phx-target={@myself}
          >
            ＋ Add Card
          </button>
        </div>
        <:actions>
          <.button phx-disable-with="Saving...">Save Base deck</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{base_deck: base_deck} = assigns, socket) do
    base_deck = Game.BaseDecks.get_base_deck!(base_deck.id)

    already_used_card_ids =
      base_deck
      |> Game.BaseDecks.BaseDeck.get_cards()
      |> Enum.map(& &1.id)
      |> dbg()

    available_cards =
      Game.BaseCards.list_basecards()

    # |> Enum.filter(&(&1.id not in already_used_card_ids))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:cards, available_cards)
     |> assign_new(:form, fn ->
       to_form(Game.BaseDecks.change_base_deck(base_deck))
     end)}
  end

  @impl true
  def handle_event("validate", %{"base_deck" => base_deck_params}, socket) do
    base_deck_params =
      if Map.has_key?(base_deck_params, "base_deck_cards") do
        Map.update!(base_deck_params, "base_deck_cards", &normalize_base_deck_cards/1)
      else
        base_deck_params
      end

    changeset = BaseDecks.change_base_deck(socket.assigns.base_deck, base_deck_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"base_deck" => base_deck_params}, socket) do
    base_deck_params =
      if Map.has_key?(base_deck_params, "base_deck_cards") do
        Map.update!(base_deck_params, "base_deck_cards", &normalize_base_deck_cards/1)
      else
        base_deck_params
      end

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

  def handle_event("add_base_deck_card", _params, socket) do
    base_deck_cards =
      (socket.assigns.form.params["base_deck_cards"] ||
         socket.assigns.form[:base_deck_cards].value || [])
      |> Enum.map(fn card -> if is_struct(card), do: Map.from_struct(card), else: card end)

    new_card = %{"card_id" => nil, "count" => 1}
    updated_cards = base_deck_cards ++ [new_card]
    params = Map.put(socket.assigns.form.params || %{}, "base_deck_cards", updated_cards)
    changeset = Game.BaseDecks.change_base_deck(socket.assigns.base_deck, params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("remove_base_deck_card", %{"idx" => idx}, socket) do
    idx = String.to_integer(idx)

    base_deck_cards =
      (socket.assigns.form.params["base_deck_cards"] ||
         socket.assigns.form[:base_deck_cards].value || [])
      |> Enum.map(fn card -> if is_struct(card), do: Map.from_struct(card), else: card end)

    updated_cards = List.delete_at(base_deck_cards, idx)
    params = Map.put(socket.assigns.form.params || %{}, "base_deck_cards", updated_cards)
    changeset = Game.BaseDecks.change_base_deck(socket.assigns.base_deck, params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  defp normalize_base_deck_cards(cards) when is_map(cards) do
    cards
    |> Map.values()
    |> Enum.map(&normalize_base_deck_card/1)
  end

  defp normalize_base_deck_cards(cards) when is_list(cards),
    do: Enum.map(cards, &normalize_base_deck_card/1)

  defp normalize_base_deck_cards(_), do: []

  defp normalize_base_deck_card(card) do
    card = if is_struct(card), do: Map.from_struct(card), else: card

    %{
      "id" => Map.get(card, "id") || Map.get(card, :id),
      "card_id" => parse_int(Map.get(card, "card_id") || Map.get(card, :card_id)),
      "count" => parse_int(Map.get(card, "count") || Map.get(card, :count))
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp parse_int(val) when is_binary(val) and val != "", do: String.to_integer(val)
  defp parse_int(val), do: val
end
