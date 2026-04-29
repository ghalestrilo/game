defmodule GameWeb.Admin.BaseClassLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Game.Content.BaseClass,
      repo: Game.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ]

  @impl Backpex.LiveResource
  def layout(_assigns), do: {GameWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Base Class"

  @impl Backpex.LiveResource
  def plural_name, do: "Base Classes"

  @impl Backpex.LiveResource
  def fields do
    [
      class: %{
        module: Backpex.Fields.Text,
        label: "Class",
        searchable: true
      },
      avatar_url: %{
        module: Backpex.Fields.Text,
        label: "Avatar URL"
      },
      base_hp: %{
        module: Backpex.Fields.Number,
        label: "Base HP"
      },
      base_ap: %{
        module: Backpex.Fields.Number,
        label: "Base AP"
      },
      base_movement: %{
        module: Backpex.Fields.Number,
        label: "Base Movement"
      },
      deck: %{
        module: Backpex.Fields.BelongsTo,
        label: "Deck",
        display_field: :name,
        live_resource: GameWeb.Admin.BaseDeckLive
      }
    ]
  end

  def changeset(item, attrs, _metadata) do
    Game.Content.BaseClass.changeset(item, attrs)
  end
end
