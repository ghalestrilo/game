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
    # TODO: remove below
    defp extract_card_info(card_id) when is_integer(card_id), do: Game.Deck.get_card_name(card_id)
    defp extract_card_info(unknown), do: "Unknown (#{inspect(unknown)})"
  end

  @doc """
  Attempts to resolve a card ID to its name by looking through available card sources.
  Returns "Unknown Card (ID: X)" if the card cannot be found.
  """
  def get_card_name(card_id) do
    all_cards = get_all_available_cards()

    case Enum.find(all_cards, fn card -> card.id == card_id end) do
      nil -> "Unknown Card (ID: #{card_id})"
      card -> card.name
    end
  end

  # Helper function to gather all available cards from current sources
  defp get_all_available_cards do
    alias Game.ClassSkills

    ClassSkills.cleric_skills() ++ ClassSkills.fighter_skills()
  end
end
