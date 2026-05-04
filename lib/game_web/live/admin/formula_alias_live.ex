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
        searchable: true
      },
      description: %{
        module: Backpex.Fields.Text,
        label: "Description"
      },
      expression: %{
        module: GameWeb.Admin.Fields.FormulaField,
        label: "Expression",
        render: fn assigns ->
          id = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
          ~H"""
          <div>
            <.live_component id={id} module={GameWeb.Components.FormulaTreeComponent} value={@item.expression}/>
          </div>
          """
        end
      }
    ]
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
