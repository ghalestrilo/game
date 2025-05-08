defmodule Game.Deck do
  defstruct [
    :id,
    # Owner of the deck
    :character_id,
    # List of card IDs
    :cards
  ]
end
