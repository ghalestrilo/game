defmodule Game.BaseCards.BaseCard do
  use Ecto.Schema
  import Ecto.Changeset

  defmodule StringOrNumber do
    @behaviour Ecto.Type
    def type, do: :string
    def cast(v) when is_binary(v), do: {:ok, v}
    def cast(v) when is_number(v), do: {:ok, to_string(v)}
    def cast(_), do: :error
    def load(v) when is_binary(v), do: {:ok, v}
    def load(v) when is_number(v), do: {:ok, to_string(v)}
    def load(_), do: :error
    def dump(v) when is_binary(v), do: {:ok, v}
    def dump(_), do: :error
    def embed_as(_), do: :self
    def equal?(a, b), do: a == b
  end

  defmodule Effect do
    use Ecto.Schema
    use StructAccess
    import Ecto.Changeset

    @derive {Jason.Encoder, only: [:type, :value, :aoe, :range, :multi, :scaling, :conditional]}
    @primary_key false
    embedded_schema do
      field :type, :string
      field :value, Game.BaseCards.BaseCard.StringOrNumber
      field :aoe, :boolean, default: false
      field :range, :integer
      field :multi, :integer
      field :scaling, :string
      field :conditional, :map
    end

    def changeset(effect, attrs) do
      effect
      |> cast(attrs, [:type, :value, :aoe, :range, :multi, :scaling, :conditional])
      |> validate_required([:type])
    end
  end

  schema "cards" do
    field :name, :string
    embeds_many :effects, Effect, on_replace: :delete
    field :ap, :integer
    field :headline, :string
    field :rarity, Ecto.Enum, values: [:common, :uncommon, :rare, :legendary]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_card, attrs) do
    base_card
    |> cast(attrs, [:name, :ap, :headline, :rarity])
    |> cast_embed(:effects,
      with: &Effect.changeset/2,
      sort_param: :effects_order,
      drop_param: :effects_delete
    )
    |> validate_required([:name, :ap, :headline, :rarity])
  end
end
