defmodule GameWeb.Admin.StrategyLive do
  use Backpex.LiveResource,
    init_order: %{by: :name, direction: :asc},
    adapter_config: [
      schema: Game.Content.Strategy,
      repo: Game.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ]

  @impl Backpex.LiveResource
  def layout(_assigns), do: {GameWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Strategy"

  @impl Backpex.LiveResource
  def plural_name, do: "Strategies"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true
      },
      tactics: %{
        module: Backpex.Fields.InlineCRUD,
        label: "Tactics",
        orderable: false,
        type: :embed,
        child_fields: [
          trigger: %{
            module: GameWeb.Admin.Fields.FormulaField,
            label: "Trigger"
          },
          action: %{
            module: Backpex.Fields.Select,
            label: "Action",
            options: [
              {"Damage", "damage"},
              {"Heal", "heal"},
              {"Shield", "shield"},
              {"Move Closer", "move_closer"},
              {"Move Away", "move_away"},
              {"Skip Turn", "skip_turn"}
            ]
          },
          card_filter: %{
            module: Backpex.Fields.Text,
            label: "Card Filter"
          }
        ]
      }
    ]
  end

  def changeset(item, attrs, _metadata) do
    attrs
    |> parse_tactic_triggers()
    |> then(&Game.Content.Strategy.changeset(item, &1))
  end

  defp parse_tactic_triggers(%{"tactics" => tactics} = attrs) when is_map(tactics) do
    parsed =
      Map.new(tactics, fn {k, tactic} ->
        {k, parse_trigger(tactic)}
      end)

    %{attrs | "tactics" => parsed}
  end

  defp parse_tactic_triggers(attrs), do: attrs

  defp parse_trigger(%{"trigger" => trigger} = tactic) when is_map(trigger) do
    %{tactic | "trigger" => Game.Formula.parse_params(trigger)}
  end

  defp parse_trigger(tactic), do: tactic
end
