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

  def kind(:shield), do: :buff
  def kind(:regen), do: :buff
  def kind(:ethereal), do: :buff
  def kind(:stealth), do: :buff
  def kind(:dot), do: :debuff
  def kind(:stun), do: :debuff
  def kind(:hex), do: :debuff
  def kind(:slow), do: :debuff
  def kind(:stuck), do: :debuff
  def kind(_), do: :neutral

  def badge_class(effect), do: badge_class_for_kind(kind(effect.type))
  defp badge_class_for_kind(:buff), do: "badge-success"
  defp badge_class_for_kind(:debuff), do: "badge-error"
  defp badge_class_for_kind(:neutral), do: "badge-info"

  def icon_for(:shield), do: "hero-shield-check-solid"
  def icon_for(:stun), do: "hero-bolt-slash-solid"
  def icon_for(:ethereal), do: "hero-cube-transparent-solid"
  def icon_for(:stealth), do: "hero-eye-slash-solid"
  def icon_for(:hex), do: "hero-arrow-path-rounded-square-solid"
  def icon_for(:dot), do: "hero-fire-solid"
  def icon_for(:regen), do: "hero-heart-solid"
  def icon_for(:slow), do: "hero-arrow-down-solid"
  def icon_for(:stuck), do: "hero-no-symbol-solid"
  def icon_for(:modify_attribute), do: "hero-adjustments-horizontal-solid"
  def icon_for(_), do: "hero-sparkles-solid"

  def get_display_text(%{
        type: :modify_attribute,
        value: value,
        duration: duration,
        attribute: attribute
      }) do
    sign = if value > 0, do: "+", else: "-"
    "#{sign}#{value} #{attribute} (#{duration} turns)"
  end

  def get_display_text(%{type: :dot, value: value, duration: duration}) do
    sign = if value > 0, do: "+", else: "-"
    "#{value} dmg/turn (#{duration} turns)"
  end

  def get_display_text(effect) do
    detail =
      effect
      |> Map.drop([:type, :value_label, :__struct__])
      |> Map.reject(fn {_, v} -> is_nil(v) or v == 0 end)
      |> Enum.map_join(" ", fn {k, v} -> "#{k}:#{v}" end)

    String.capitalize(Atom.to_string(effect.type)) <>
      if detail != "", do: " (#{detail})", else: ""
  end
end
