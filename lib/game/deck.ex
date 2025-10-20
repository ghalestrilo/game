defmodule Game.Deck do
  defstruct [
    :id,
    # Owner of the deck
    :character_id,
    # List of card IDs
    :cards
  ]

  defimpl Inspect do
    def inspect(deck, _opts) do
      card_counts =
        deck.cards
        |> Enum.map(&extract_card_info/1)
        |> Enum.frequencies()
        |> Enum.map(fn {card_name, count} ->
          "#{card_name}: #{count}"
        end)
        |> Enum.join(", ")

      "#Deck<id: #{deck.id}, character_id: #{deck.character_id}, cards: [#{card_counts}]>"
    end

    # Extract card name from either a Card struct or card ID
    defp extract_card_info(%Game.Card{name: name}), do: name
  end
end
