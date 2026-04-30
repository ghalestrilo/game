defmodule Game.Content.Strategy do
  use Ecto.Schema
  import Ecto.Changeset

  defmodule Tactic do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :trigger, :map, default: %{}
      field :action, :string
      field :card_filter, :string
    end

    def changeset(tactic, attrs) do
      tactic
      |> cast(attrs, [:trigger, :action, :card_filter])
      |> validate_required([:action])
    end
  end

  schema "strategies" do
    field :name, :string
    embeds_many :tactics, Tactic, on_replace: :delete
    has_many :base_classes, Game.Content.BaseClass

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:name])
    |> cast_embed(:tactics,
      with: &Tactic.changeset/2,
      sort_param: :tactics_order,
      drop_param: :tactics_delete
    )
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
