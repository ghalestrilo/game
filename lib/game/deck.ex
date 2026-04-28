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
      card_frequencies =
        deck.cards
        |> Enum.map(&extract_card_info/1)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {name, _count} -> name end)

      format_table(card_frequencies)
    end

    # Extract card name from either a Card struct or card ID
    defp extract_card_info(%Game.Card{name: name}), do: name

    defp format_table(card_frequencies) do
      # Find the maximum name length for column width
      max_name_length =
        card_frequencies
        |> Enum.map(fn {name, _count} -> String.length(name) end)
        |> Enum.max(fn -> 4 end)

      # Ensure minimum width for "name" header
      name_col_width = max(max_name_length, 4)

      # Count column width (minimum for "count" header)
      count_col_width = 5

      # Build separator line
      separator =
        "+" <>
          String.duplicate("-", name_col_width + 2) <>
          "+" <> String.duplicate("-", count_col_width + 2) <> "+"

      # Build header
      header =
        "| " <>
          String.pad_trailing("name", name_col_width) <>
          " | " <> String.pad_trailing("count", count_col_width) <> " |"

      # Build rows
      rows =
        Enum.map(card_frequencies, fn {name, count} ->
          "| " <>
            String.pad_trailing(name, name_col_width) <>
            " | " <> String.pad_trailing(to_string(count), count_col_width) <> " |"
        end)

      # Combine all parts
      [separator, header, separator | rows]
      |> Enum.concat([separator])
      |> Enum.join("\n")
    end
  end
end
