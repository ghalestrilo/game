alias Game.Repo
import Ecto.Query

cards = Repo.all(from c in "cards", select: %{id: c.id, effects: c.effects})

Enum.each(cards, fn %{id: id, effects: effects} ->
  range =
    effects
    |> List.wrap()
    |> Enum.map(&Map.get(&1, "range"))
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
    |> then(&(&1 || 1))

  Repo.update_all(from(c in "cards", where: c.id == ^id), set: [range: range])
  IO.puts("card #{id}: range = #{range}")
end)

IO.puts("Done.")
