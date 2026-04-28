defmodule GameWeb.Admin.BaseCardLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Game.BaseCards.BaseCard,
      repo: Game.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ]

  @impl Backpex.LiveResource
  def layout(_assigns), do: {GameWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Base Card"

  @impl Backpex.LiveResource
  def plural_name, do: "Base Cards"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true
      },
      headline: %{
        module: Backpex.Fields.Text,
        label: "Headline"
      },
      ap: %{
        module: Backpex.Fields.Number,
        label: "AP"
      },
      rarity: %{
        module: Backpex.Fields.Select,
        label: "Rarity",
        options: [
          {"Common", :common},
          {"Uncommon", :uncommon},
          {"Rare", :rare},
          {"Legendary", :legendary}
        ]
      },
      effects: %{
        module: Backpex.Fields.InlineCRUD,
        label: "Effects",
        type: :embed,
        child_fields: [
          type: %{
            module: Backpex.Fields.Text,
            label: "Type"
          },
          value: %{
            module: Backpex.Fields.Text,
            label: "Value"
          }
        ]
      }
    ]
  end

  def changeset(item, attrs, _metadata) do
    Game.BaseCards.BaseCard.changeset(item, attrs)
  end
end
