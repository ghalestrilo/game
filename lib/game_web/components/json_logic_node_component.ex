defmodule GameWeb.Components.FormulaTreeComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="jl-node">
      {inspect(@value)}
    </div>
    """
  end

  # # ---------- OPERATOR RENDERING ----------

  # # Logical
  # defp render_op(%{ "and" => args} = assigns) do
  #   ~H"""
  #   <div class="jl-group jl-and">
  #     <span class="jl-label">ALL</span>
  #     <div class="jl-children vertical">
  #       <%= for {child, i} <- Enum.with_index(args) do %>
  #         <.child node={child} idx={i} parent_id={@id} />
  #       <% end %>
  #     </div>
  #   </div>
  #   """
  # end

  # defp render_op(%{"or" => args} = assigns) do
  #   ~H"""
  #   <div class="jl-group jl-or">
  #     <span class="jl-label">ANY</span>
  #     <div class="jl-children vertical">
  #       <%= for {child, i} <- Enum.with_index(args) do %>
  #         <.child node={child} idx={i} parent_id={@id} />
  #       <% end %>
  #     </div>
  #   </div>
  #   """
  # end

  # # Comparison
  # defp render_op(%{ op => [a, b] } = assigns)
  #      when op in ["==", "!=", ">", "<", ">=", "<="] do
  #   ~H"""
  #   <div class="jl-binary">
  #     <.child node={a} idx={0} parent_id={@id} />
  #     <span class="jl-op"><%= op %></span>
  #     <.child node={b} idx={1} parent_id={@id} />
  #   </div>
  #   """
  # end

  # Arithmetic
  # defp render_op(%{ op => args} = assigns)
  #      when op in ["+", "-", "*", "/"] do
  #   ~H"""
  #   <div class="jl-binary">
  #     <%= for {child, i} <- Enum.with_index(args) do %>
  #       <.child node={child} idx={i} parent_id={@id} />
  #       <%= if i < length(args) - 1 do %>
  #         <span class="jl-op"><%= op %></span>
  #       <% end %>
  #     <% end %>
  #   </div>
  #   """
  # end

  # # IF
  # defp render_op(%{ "if" => args } = assigns) do
  #   ~H"""
  #   <div class="jl-if">
  #     <%= for chunk <- Enum.chunk_every(args, 2) do %>
  #       <%= case chunk do %>
  #         <% [cond, result] -> %>
  #           <div class="jl-if-row">
  #             <span class="jl-if-label">IF</span>
  #             <.child node={cond} idx={0} parent_id={@id} />

  #             <span class="jl-if-label">THEN</span>
  #             <.child node={result} idx={1} parent_id={@id} />
  #           </div>

  #         <% [else_val] -> %>
  #           <div class="jl-if-row">
  #             <span class="jl-if-label">ELSE</span>
  #             <.child node={else_val} idx={0} parent_id={@id} />
  #           </div>
  #       <% end %>
  #     <% end %>
  #   </div>
  #   """
  # end

  # # var
  # defp render_op(%{"var" => key}) do
  #   ~H"""
  #   <span class="jl-var">var(<%= render_value(key) %>)</span>
  #   """
  # end

  # # missing / missing_some
  # defp render_op(%{op => args} = assigns)
  #      when op in ["missing", "missing_some"] do
  #   ~H"""
  #   <div class="jl-fn">
  #     <span class="jl-label"><%= op %></span>
  #     <%= for {child, i} <- Enum.with_index(args) do %>
  #       <.child node={child} idx={i} parent_id={@id} />
  #     <% end %>
  #   </div>
  #   """
  # end

  # # ---------- FALLBACK (important) ----------

  # defp render_op(%{ op => args } = assigns) do
  #   ~H"""
  #   <div class="jl-unknown">
  #     <span class="jl-label"><%= op %></span>

  #     <div class="jl-children">
  #       <%= for {child, i} <- Enum.with_index(args) do %>
  #         <.child node={child} idx={i} parent_id={@id} />
  #       <% end %>
  #     </div>
  #   </div>
  #   """
  # end

  # # ---------- CHILD HELPER ----------

  # defp child(assigns) do
  #   ~H"""
  #   <.live_component
  #     module={__MODULE__}
  #     id={"#{@parent_id}-#{@idx}"}
  #     node={@node}
  #   />
  #   """
  # end

  # # ---------- VALUE RENDER ----------

  # defp render_value(%{"var" => v}), do: "var(#{v})"
  # defp render_value(v) when is_binary(v), do: ~s("#{v}")
  # defp render_value(v), do: inspect(v)
end
