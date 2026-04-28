defmodule Game.BaseDecks.BaseDeck do
  use Ecto.Schema
  import Ecto.Changeset

  alias Game.Content.BaseDeckCard, as: BaseDeckCard

  schema "decks" do
    field :name, :string
    has_many :base_deck_cards, BaseDeckCard, foreign_key: :deck_id, on_replace: :delete
    has_many :cards, through: [:base_deck_cards, :card]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(base_deck, attrs) do
    base_deck
    |> cast(attrs, [:name])
    |> cast_assoc(:base_deck_cards,
      with: &Game.Content.BaseDeckCard.changeset/2,
      sort_param: :base_deck_cards_order,
      drop_param: :base_deck_cards_delete
    )
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def get_cards(%Game.BaseDecks.BaseDeck{base_deck_cards: cards}) do
    cards
    |> Enum.flat_map(
      &([&1.card]
        |> Stream.cycle()
        |> Enum.take(&1.count)
        |> Enum.to_list())
    )
    |> Enum.map(&base_card_to_card/1)
    |> Enum.with_index()
    |> Enum.map(fn {card, idx} -> %{card | id: idx} end)
  end

  defp base_card_to_card(card) do
    card =
      card
      |> Map.drop([:__meta__, :__struct__, :inserted_at, :updated_at, :ap, :headline])
      |> Map.merge(%{
        cost: card.ap
      })

    struct!(Game.Card, card)
  end
end
