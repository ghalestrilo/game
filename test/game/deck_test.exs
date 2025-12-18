defmodule Game.DeckTest do
  use ExUnit.Case, async: true

  alias Game.Deck
  alias Game.Card

  describe "Inspect implementation" do
    test "displays ASCII table with card names and counts" do
      cards = [
        %Card{id: 1, name: "Fire Blast", cost: 2},
        %Card{id: 2, name: "Ice Shield", cost: 1},
        %Card{id: 3, name: "Fire Blast", cost: 2},
        %Card{id: 4, name: "Lightning Strike", cost: 3},
        %Card{id: 5, name: "Fire Blast", cost: 2}
      ]

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +------------------+-------+
      | name             | count |
      +------------------+-------+
      | Fire Blast       | 3     |
      | Ice Shield       | 1     |
      | Lightning Strike | 1     |
      +------------------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "displays empty table for deck with no cards" do
      deck = %Deck{id: 1, character_id: 1, cards: []}

      expected = """
      +------+-------+
      | name | count |
      +------+-------+
      +------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "handles single card" do
      cards = [
        %Card{id: 1, name: "Solo Card", cost: 1}
      ]

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +-----------+-------+
      | name      | count |
      +-----------+-------+
      | Solo Card | 1     |
      +-----------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "sorts cards alphabetically by name" do
      cards = [
        %Card{id: 1, name: "Zebra Card", cost: 1},
        %Card{id: 2, name: "Alpha Card", cost: 1},
        %Card{id: 3, name: "Beta Card", cost: 1}
      ]

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +------------+-------+
      | name       | count |
      +------------+-------+
      | Alpha Card | 1     |
      | Beta Card  | 1     |
      | Zebra Card | 1     |
      +------------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "handles cards with long names" do
      cards = [
        %Card{id: 1, name: "A Very Long Card Name That Should Expand The Column Width", cost: 1},
        %Card{id: 2, name: "Short", cost: 1}
      ]

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +-----------------------------------------------------------+-------+
      | name                                                      | count |
      +-----------------------------------------------------------+-------+
      | A Very Long Card Name That Should Expand The Column Width | 1     |
      | Short                                                     | 1     |
      +-----------------------------------------------------------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "counts duplicate cards correctly" do
      cards = [
        %Card{id: 1, name: "Duplicate", cost: 1},
        %Card{id: 2, name: "Duplicate", cost: 1},
        %Card{id: 3, name: "Duplicate", cost: 1},
        %Card{id: 4, name: "Duplicate", cost: 1},
        %Card{id: 5, name: "Duplicate", cost: 1}
      ]

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +-----------+-------+
      | name      | count |
      +-----------+-------+
      | Duplicate | 5     |
      +-----------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "handles multiple different cards with various counts" do
      cards = [
        %Card{id: 1, name: "Common Card", cost: 1},
        %Card{id: 2, name: "Common Card", cost: 1},
        %Card{id: 3, name: "Common Card", cost: 1},
        %Card{id: 4, name: "Rare Card", cost: 5},
        %Card{id: 5, name: "Uncommon Card", cost: 3},
        %Card{id: 6, name: "Uncommon Card", cost: 3}
      ]

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +---------------+-------+
      | name          | count |
      +---------------+-------+
      | Common Card   | 3     |
      | Rare Card     | 1     |
      | Uncommon Card | 2     |
      +---------------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "handles short card names" do
      cards = [
        %Card{id: 1, name: "A", cost: 1},
        %Card{id: 2, name: "B", cost: 1}
      ]

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +------+-------+
      | name | count |
      +------+-------+
      | A    | 1     |
      | B    | 1     |
      +------+-------+\
      """

      assert inspect(deck) == expected
    end

    test "handles large counts" do
      cards = List.duplicate(%Card{id: 1, name: "Many", cost: 1}, 42)

      deck = %Deck{id: 1, character_id: 1, cards: cards}

      expected = """
      +------+-------+
      | name | count |
      +------+-------+
      | Many | 42    |
      +------+-------+\
      """

      assert inspect(deck) == expected
    end
  end
end
