defmodule Game.Character do
  defstruct id: nil,
            name: nil,
            class: nil,
            # Action Points
            ap: nil,
            # Health Points
            hp: nil,
            # Cards structure with draw, hand, and discard piles
            cards: %{
              draw: [],
              hand: [],
              discard: []
            },
            # Hex grid position {q, r, s}
            position: nil,
            # List of active status effects
            status_effects: nil,
            # Movement range in tiles
            movement_range: nil,
            # Team identifier
            team: nil

  @type t() :: %__MODULE__{
          id: integer(),
          name: String.t(),
          class: atom(),
          ap: integer(),
          hp: integer(),
          cards: %{
            draw: list(Card.t()),
            hand: list(Card.t()),
            discard: list(Card.t())
          },
          position: {integer(), integer(), integer()},
          status_effects: list(atom()),
          movement_range: integer(),
          team: atom()
        }

  @doc """
  Moves a character to a new position
  """
  def move(character, target_position) do
    %{character | position: target_position}
  end

  @doc """
  Returns true if the character is dead (hp <= 0)
  """
  def is_dead?(%__MODULE__{hp: hp}) when is_integer(hp), do: hp <= 0
  def is_dead?(_), do: false

  @doc """
  Returns true if the character has enough AP for the given cost
  """
  def has_enough_ap?(%__MODULE__{ap: ap}, cost) when is_integer(ap), do: ap >= cost
  def has_enough_ap?(_, _), do: false

  @doc """
  Applies damage to a character
  """
  def apply_damage(character, amount) do
    %{character | hp: character.hp - amount}
  end

  @doc """
  Heals a character
  """
  def heal(character, amount) do
    # Cap healing at max HP (which is the initial HP value)
    max_hp =
      case character.class do
        :fighter -> 20
        :mage -> 15
        _ -> 15
      end

    %{character | hp: min(character.hp + amount, max_hp)}
  end

  @doc """
  Applies a card effect to a character
  """
  def apply_card_effect(character, {:damage, amount}), do: apply_damage(character, amount)
  def apply_card_effect(character, {:heal, amount}), do: heal(character, amount)
  def apply_card_effect(character, _), do: character

  @doc """
  Moves a card from one pile to another
  """
  def move_card(character, card, from_pile, to_pile) do
    # Remove card from source pile
    updated_from = Enum.reject(Map.get(character.cards, from_pile), fn c -> c.id == card.id end)

    # Add card to destination pile
    updated_to = [card | Map.get(character.cards, to_pile)]

    # Update character with new card piles
    %{character | cards: Map.put(Map.put(character.cards, from_pile, updated_from), to_pile, updated_to)}
  end

  @doc """
  Draws cards from draw pile to hand
  """
  def draw_cards(character, count) do
    {cards_to_draw, remaining_draw} = Enum.split(character.cards.draw, count)

    # Update character with new draw pile and hand
    %{character | cards: %{
      character.cards |
      draw: remaining_draw,
      hand: character.cards.hand ++ cards_to_draw
    }}
  end

  @doc """
  Discards a card from hand
  """
  def discard_card(character, card) do
    move_card(character, card, :hand, :discard)
  end

  @doc """
  Shuffles discard pile into draw pile
  """
  def shuffle_discard_into_draw(character) do
    shuffled_cards = Enum.shuffle(character.cards.discard)

    %{character | cards: %{
      character.cards |
      draw: character.cards.draw ++ shuffled_cards,
      discard: []
    }}
  end
end
