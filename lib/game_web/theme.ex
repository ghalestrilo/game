defmodule GameWeb.Theme do
  @team_colors ~w(
    border-sky-500
    border-rose-500
    border-emerald-500
    border-amber-500
    border-violet-500
    border-orange-500
    border-teal-500
    border-pink-500
  )

  @team_bg_colors ~w(
    bg-sky-500
    bg-rose-500
    bg-emerald-500
    bg-amber-500
    bg-violet-500
    bg-orange-500
    bg-teal-500
    bg-pink-500
  )

  def rarity_bg_class(:common), do: "bg-common"
  def rarity_bg_class(:uncommon), do: "bg-uncommon"
  def rarity_bg_class(:rare), do: "bg-rare"
  def rarity_bg_class(:legendary), do: "bg-legendary"
  def rarity_bg_class(_), do: "bg-base-300"

  def card_z_index_class(1), do: "z-1"
  def card_z_index_class(2), do: "z-2"
  def card_z_index_class(3), do: "z-3"
  def card_z_index_class(4), do: "z-4"
  def card_z_index_class(5), do: "z-5"
  def card_z_index_class(6), do: "z-6"
  def card_z_index_class(_), do: "z-0"

  def rarity_bg_class(:common, :soft), do: "bg-common/20"
  def rarity_bg_class(:uncommon, :soft), do: "bg-uncommon/20"
  def rarity_bg_class(:rare, :soft), do: "bg-rare/20"
  def rarity_bg_class(:legendary, :soft), do: "bg-legendary/20"
  def rarity_bg_class(_, _), do: "bg-base-300/20"

  def team_ring_class(team) when is_integer(team) do
    Enum.at(@team_colors, rem(team, length(@team_colors)))
  end

  def team_ring_class(team) do
    index = team |> String.to_charlist() |> Enum.sum() |> rem(length(@team_colors))
    Enum.at(@team_colors, index)
  end

  def team_bg_class(team) when is_integer(team) do
    Enum.at(@team_bg_colors, rem(team, length(@team_bg_colors)))
  end

  def team_bg_class(team) do
    index = team |> String.to_charlist() |> Enum.sum() |> rem(length(@team_bg_colors))
    Enum.at(@team_bg_colors, index)
  end
end
