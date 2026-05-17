defmodule Game.Character do
  defstruct id: nil,
            name: nil,
            class: nil,
            avatar_url: nil,
            # Action Points
            ap: nil,
            max_ap: nil,
            # Health Points
            hp: nil,
            max_hp: nil,
            # Cards structure with draw, hand, and discard piles
            cards: %{
              draw: [],
              hand: [],
              discard: []
            },
            # Hex grid position {q, r, s}
            position: nil,
            # List of active status effects
            status_effects: [],
            # Movement range in tiles
            movement_range: nil,
            # Cards drawn at the start of each turn
            hand_size: 5,
            # Multiplier applied to incoming damage (>1.0 = takes more; <1.0 = takes less)
            damage_multiplier: 1.0,
            # Team identifier
            team: nil,
            dead: false,
            # AI strategy tactics (empty = human-controlled)
            tactics: []

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
  Applies damage to a character, accounting for shield status effects
  """
  def apply_damage(character, amount) when amount < 0 do
    # Healing (negative amount): hex flips it to damage
    effective = if get_status_effect(character, :hex), do: -amount, else: amount
    %{character | hp: character.hp - effective}
  end

  def apply_damage(character, amount) do
    multiplied = round(amount * effective_attribute(character, "damage_multiplier"))
    shield = get_status_effect(character, :shield)

    {char_after_shield, hp_damage} =
      case shield do
        %{value: shield_value} when shield_value > 0 ->
          if shield_value >= multiplied do
            {update_status_effect(character, %{shield | value: shield_value - multiplied}), 0}
          else
            {remove_status_effect(character, :shield), multiplied - shield_value}
          end

        _ ->
          {character, multiplied}
      end

    # Hex flips the post-shield damage: positive damage becomes healing (negative)
    effective_damage = if get_status_effect(character, :hex), do: -hp_damage, else: hp_damage
    %{char_after_shield | hp: char_after_shield.hp - effective_damage}
  end

  @doc """
  Heals a character
  """
  @deprecated "use -apply_damage instead"
  def apply_healing(character, amount) do
    %{character | hp: min(character.hp + amount, get_max_hp(character))}
  end

  @doc """
  Adds a status effect to a character
  """
  def add_status_effect(character, status_effect) do
    %{character | status_effects: [status_effect | character.status_effects]}
  end

  @doc """
  Gets a status effect by type from a character
  Returns nil if not found
  """
  def get_status_effect(character, type) do
    Enum.find(character.status_effects, fn effect -> effect.type == type end)
  end

  @doc """
  Updates an existing status effect
  """
  def update_status_effect(character, updated_effect) do
    updated_effects =
      Enum.map(character.status_effects, fn effect ->
        if effect.type == updated_effect.type, do: updated_effect, else: effect
      end)

    %{character | status_effects: updated_effects}
  end

  @doc """
  Removes a status effect by type from a character
  """
  def remove_status_effect(character, type) do
    updated_effects = Enum.reject(character.status_effects, fn effect -> effect.type == type end)
    %{character | status_effects: updated_effects}
  end

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
  Discards a player's entire hand into their discard pile
  """
  def discard_hand(%__MODULE__{cards: cards} = character) do
    # Preserve any cards that might be needed for tests
    %__MODULE__{character | cards: %{cards | hand: [], discard: cards.discard ++ cards.hand}}
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
  def get_max_hp(%__MODULE__{max_hp: max_hp} = _character) do
    max_hp
  end

  # def get_max_hp(%__MODULE__{max_hp: max_hp}), do: max_hp

  def get_max_ap(%__MODULE__{max_ap: max_ap} = _character) do
    max_ap
  end

  def effective_attribute(%__MODULE__{} = character, attr) when is_binary(attr) do
    base = Map.get(character, String.to_existing_atom(attr))

    Enum.reduce(character.status_effects, base, fn
      %{type: :modify_attribute, attribute: ^attr, value: v}, acc -> acc + to_number(v)
      _, acc -> acc
    end)
  end

  def from_character_data(%Game.Content.BaseClass{} = base_class) do
    tactics =
      case base_class.strategy do
        %Game.Content.Strategy{tactics: tactics} ->
          Enum.map(tactics, fn t ->
            %{"trigger" => t.trigger, "action" => t.action, "card_filter" => t.card_filter}
          end)

        _ ->
          []
      end

    %__MODULE__{
      id: base_class.id,
      name: String.capitalize(base_class.class),
      class: base_class.class,
      avatar_url: base_class.avatar_url,
      hp: base_class.base_hp,
      max_hp: base_class.base_hp,
      ap: base_class.base_ap,
      max_ap: base_class.base_ap,
      movement_range: base_class.base_movement,
      position: {0, 0},
      cards: %{
        draw: Game.BaseDecks.BaseDeck.get_cards(base_class.deck),
        hand: [],
        discard: []
      },
      tactics: tactics
    }
  end

  def is_ai_controlled?(%__MODULE__{tactics: [_ | _]}), do: true
  def is_ai_controlled?(_), do: false

  def shuffle_deck(character) do
    update_in(character.cards.draw, &Enum.shuffle(&1))
  end

  defp to_number(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_number(n), do: n
end
