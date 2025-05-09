defmodule Game.Character do
  defstruct id: nil,
            name: nil,
            class: nil,
            # Action Points
            ap: nil,
            # Health Points
            hp: nil,
            # List of Cards
            deck: nil,
            # Hex grid position {q, r, s}
            position: nil,
            # List of active status effects
            status_effects: nil,
            # Cards in hand
            hand: [],
            # Movement range in tiles
            movement_range: nil,
            # Team identifier
            team: nil

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
    %{character | hp: character.hp + amount}
  end

  @doc """
  Applies a card effect to a character
  """
  def apply_card_effect(character, {:damage, amount}), do: apply_damage(character, amount)
  def apply_card_effect(character, {:heal, amount}), do: heal(character, amount)
  def apply_card_effect(character, _), do: character
end
