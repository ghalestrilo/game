defmodule GameWeb.BaseCardLive.FormComponent do
  use GameWeb, :live_component

  alias Game.BaseCards

  @effect_types [
    "burn",
    "cleanse",
    "damage",
    "dodge",
    "draw",
    "growth",
    "heal",
    "move",
    "poison",
    "position",
    "regen",
    "root",
    "shield",
    "slow",
    "stealth",
    "stun",
    "taunt"
  ]

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
        <div id="effects-list" class="flex gap-2 flex-col items-baseline">
          <%!-- <div id="effects-list gap-2 flex-col"> --%>
          <label>Effects</label>
          <%= for {effect, idx} <- Enum.with_index(@form[:effects].value || []) do %>
            <% effect = if is_tuple(effect), do: elem(effect, 1), else: effect %>
            <div
              class="flex w-full gap-4 items-end justify-between [&_div]:w-full"
              id={"effect-#{idx}"}
            >
              <.input
                class="flex-1 w-full"
                name={"#{@form.name}[effects][#{idx}][type]"}
                id={"#{@form.id}_effects_#{idx}_type"}
                value={effect["type"]}
                type="select"
                label="Effect Type"
                options={@effect_types}
              />
              <.input
                class="flex-1 w-full"
                name={"#{@form.name}[effects][#{idx}][value]"}
                id={"#{@form.id}_effects_#{idx}_value"}
                value={effect["value"]}
                type="number"
                label="Effect Value"
              />
              <button
                type="button"
                class="my-[10px]"
                phx-click="remove_effect"
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
            phx-click="add_effect"
            phx-target={@myself}
          >
            ＋ Add Effect
          </button>
        </div>
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
     end)
     |> assign(:effect_types, @effect_types)}
  end

  @impl true
  def handle_event("validate", %{"base_card" => base_card_params}, socket) do
    changeset = BaseCards.change_base_card(socket.assigns.base_card, base_card_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("add_effect", _params, socket) do
    effects = socket.assigns.form[:effects].value || []
    new_effect = %{"type" => List.first(@effect_types), "value" => 0}
    updated_effects = effects ++ [new_effect]
    params = Map.put(socket.assigns.form.params || %{}, "effects", updated_effects)
    changeset = BaseCards.change_base_card(socket.assigns.base_card, params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("remove_effect", %{"idx" => idx}, socket) do
    idx = String.to_integer(idx)
    effects = socket.assigns.form[:effects].value || []
    updated_effects = List.delete_at(effects, idx)
    params = Map.put(socket.assigns.form.params || %{}, "effects", updated_effects)
    changeset = BaseCards.change_base_card(socket.assigns.base_card, params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"base_card" => base_card_params}, socket) do
    base_card_params =
      if Map.has_key?(base_card_params, "effects") do
        Map.update!(base_card_params, "effects", &normalize_effects/1)
      else
        base_card_params
      end

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
  defp normalize_effects(effects) when is_map(effects) do
    effects
    |> Map.values()
    |> Enum.map(fn effect ->
      %{
        "type" => effect["type"],
        "value" => parse_int(effect["value"])
      }
    end)
  end

  defp normalize_effects(effects) when is_list(effects), do: effects
  defp normalize_effects(_), do: []

  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(val), do: val
end
