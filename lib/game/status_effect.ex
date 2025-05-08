defmodule Game.StatusEffect do
  defstruct [
    :id,
    :name,
    :description,
    # How long the effect lasts
    :duration,
    # List of modifications to apply (damage multipliers, AP cost changes, etc.)
    :modifiers,
    # Function reference for removing the effect
    :removal_condition
  ]
end
