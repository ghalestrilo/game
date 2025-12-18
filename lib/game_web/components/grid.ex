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

    IO.inspect(rendered_html, label: "Rendered HTML in GameWeb.Grid")
    rendered_html
  end
end
