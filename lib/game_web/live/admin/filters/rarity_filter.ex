defmodule GameWeb.Admin.Filters.RarityFilter do
  use Backpex.Filters.Select

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Rarity"

  @impl Backpex.Filters.Select
  def prompt, do: "All rarities"

  @impl Backpex.Filters.Select
  def options(_assigns) do
    [{"Common", :common}, {"Uncommon", :uncommon}, {"Rare", :rare}, {"Legendary", :legendary}]
  end

  @impl Backpex.Filter
  def query(query, _attribute, value, _assigns) do
    query
    |> where([card], card.rarity == ^to_string(value))
  end
end
