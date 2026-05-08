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

  def get_display_text(%{type: :modify_attribute, value: value, duration: duration, attribute: attribute}) do
    sign = if value > 0, do: "+", else: "-"
    "#{sign}#{value} #{attribute} (#{duration} turns)"
  end

  def get_display_text(%{type: :dot, value: value, duration: duration}) do
    sign = if value > 0, do: "+", else: "-"
    "#{value} dmg/turn (#{duration} turns)"
  end

  def get_display_text(effect) do
      detail = effect
      |> Map.drop([:type, :value_label, :__struct__])
      |> Map.reject(fn {_, v} -> is_nil(v) or v == 0 end)
      |> Enum.map_join(" ", fn {k, v} -> "#{k}:#{v}" end)

      String.capitalize(Atom.to_string(effect.type)) <> if detail != "", do: " (#{detail})", else: ""
  end
end
