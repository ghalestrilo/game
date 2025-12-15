defmodule GameWeb.ShopLive do
  use Phoenix.LiveComponent
  import GameWeb.CoreComponents

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="shop-container mt-8 p-6 bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg shadow-lg">
      <div class="text-center mb-8">
        <h2 class="text-4xl font-bold text-purple-900 mb-2">The Shop</h2>
        <p class="text-lg text-purple-700">Choose your cards wisely</p>
      </div>

      <div class="shop-cards flex flex-wrap justify-center gap-6">
        <%= for {card, index} <- Enum.with_index(@game_state.combat.shop_cards) do %>
          <.card
            selected={false}
            index={index}
            card={card}
          />
        <% end %>
      </div>
    </div>
    """
  end
end
