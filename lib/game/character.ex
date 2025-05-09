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

  def move(character, target_position) do
    %{character | position: target_position}
  end
end
