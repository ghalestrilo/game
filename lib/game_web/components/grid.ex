defmodule GameWeb.Grid do
  use Phoenix.LiveComponent

  def render(assigns) do
    rendered_html = ~H"""
    <div class="grid-container">
      <svg viewBox="-100 -100 200 200" class="hex-grid">
        <%= for {_q, _r, _s, style} <- @tiles do %>
          <polygon points="#{hex_points(q, r)}" class="hex-tile filled" style={style} />
        <% end %>
      </svg>
    </div>

    <style>
      .hex-grid {
        width: 100%;
        height: 100%;
      }
      .hex-tile {
        fill: none;
        stroke: black;
        stroke-width: 1;
      }
      .hex-tile.filled {
        fill: black;
      }
    </style>
    """

    rendered_html
  end

  def hex_points(q, r) do
    # Adjust tile size as needed
    size = 10
    angle = :math.pi() / 3

    for i <- 0..5 do
      angle_offset = angle * i
      x = size * :math.cos(angle_offset) + q * size * 1.5
      y = size * :math.sin(angle_offset) + r * size * :math.sqrt(3)
      "#{x},#{y}"
    end
    |> Enum.join(" ")
  end
end
