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
    %{character | hp: min(character.hp + amount, get_max_hp(character))}
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
    %{
      character
      | cards: Map.put(Map.put(character.cards, from_pile, updated_from), to_pile, updated_to)
    }
  end

  @doc """
  Draws cards from draw pile to hand
  If draw pile doesn't have enough cards, reshuffles discard pile into draw pile first
  """
  def draw_cards(character, count) do
    # Check if we need to reshuffle discard into draw
    character_with_reshuffled_cards =
      if length(character.cards.draw) < count && length(character.cards.discard) > 0 do
        shuffle_discard_into_draw(character)
      else
        character
      end

    # Calculate how many cards we can actually draw
    available_cards = length(character_with_reshuffled_cards.cards.draw)
    cards_to_draw_count = min(count, available_cards)

    # Draw available cards
    {cards_to_draw, remaining_draw} =
      Enum.split(character_with_reshuffled_cards.cards.draw, cards_to_draw_count)

    # Update character with new draw pile and hand
    %{
      character_with_reshuffled_cards
      | cards: %{
          character_with_reshuffled_cards.cards
          | draw: remaining_draw,
            hand: character_with_reshuffled_cards.cards.hand ++ cards_to_draw
        }
    }
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

    %{
      character
      | cards: %{
          character.cards
          | draw: character.cards.draw ++ shuffled_cards,
            discard: []
        }
    }
  end

  @doc """
  Spends AP for a given cost
  """
  def spend_ap(character, cost) do
    %{character | ap: max(0, character.ap - cost)}
  end

  defimpl Jason.Encoder, for: Game.Character do
    def encode(character, opts) do
      # Convert position tuple to list representation for JSON encoding
      character_map = Map.from_struct(character)

      position_list =
        case character_map.position do
          tuple when is_tuple(tuple) -> Tuple.to_list(tuple)
          other -> other
        end

      # Create a new map with list position
      character_map = Map.put(character_map, :position, position_list)

      Jason.Encode.map(character_map, opts)
    end
  end

  @doc """
  TODO: These methods (get_max_ap and get_max_hp) should be replaced
  once we have logic to store the characters' max_hp and max_hp somewhere safe
  """
  def get_max_hp(%__MODULE__{class: :fighter}), do: 20
  def get_max_hp(%__MODULE__{class: :mage}), do: 15
  def get_max_hp(%__MODULE__{}), do: 15

  def get_max_ap(%__MODULE__{class: :fighter}), do: 3
  def get_max_ap(%__MODULE__{class: :mage}), do: 3
  def get_max_ap(%__MODULE__{}), do: 3
end
