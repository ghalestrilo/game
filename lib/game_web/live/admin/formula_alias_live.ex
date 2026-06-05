defmodule GameWeb.Admin.FormulaAliasLive do
  use Backpex.LiveResource,
    init_order: %{by: :name, direction: :asc},
    per_page_default: 100,
    adapter_config: [
      schema: Game.FormulaAliases.FormulaAlias,
      repo: Game.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ]

  @impl Backpex.LiveResource
  def layout(_assigns), do: {GameWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Formula Alias"

  @impl Backpex.LiveResource
  def plural_name, do: "Formula Aliases"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        default: fn assigns -> Map.get(assigns.params, "name") end
      },
      description: %{
        module: Backpex.Fields.Text,
        label: "Description",
        default: fn assigns -> Map.get(assigns.params, "description") end
      },
      expression: %{
        module: GameWeb.Admin.Fields.FormulaField,
        label: "Expression",
        render: fn assigns ->
          id = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
          assigns = assign(assigns, id: id)

          ~H"""
          <div>
            <.live_component
              id={@id}
              module={GameWeb.Components.FormulaTreeComponent}
              value={@item.expression}
            />
          </div>
          """
        end,
        default: fn assigns ->
          case Map.get(assigns.params, "clone_expression") do
            s when s in [nil, ""] -> nil
            json -> with {:ok, v} <- Jason.decode(json), do: v
          end
        end
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    Enum.concat(default_actions, clone: %{module: __MODULE__.Clone, only: [:row]})
  end

  defmodule Clone do
    use BackpexWeb, :item_action

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H"""
      <Backpex.HTML.CoreComponents.icon
        name="hero-document-duplicate"
        class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110"
      />
      """
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Clone"

    @impl Backpex.ItemAction
    def link(assigns, item) do
      Backpex.Router.get_path(assigns.socket, assigns.live_resource, assigns.params, :new, %{
        "name" => "Copy of #{item.name}",
        "description" => item.description || "",
        "clone_expression" => Jason.encode!(item.expression || %{})
      })
    end
  end

  def changeset(item, attrs, _metadata) do
    attrs
    |> parse_expression()
    |> then(&Game.FormulaAliases.FormulaAlias.changeset(item, &1))
  end

  defp parse_expression(%{"expression" => expr} = attrs) when is_map(expr) do
    %{attrs | "expression" => Game.Formula.parse_params(expr)}
  end

  defp parse_expression(attrs), do: attrs
end
