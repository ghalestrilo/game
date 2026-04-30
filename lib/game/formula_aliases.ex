defmodule Game.FormulaAliases do
  import Ecto.Query
  alias Game.Repo
  alias Game.FormulaAliases.FormulaAlias

  def list_formula_aliases do
    Repo.all(from fa in FormulaAlias, order_by: fa.name)
  end

  def get_formula_alias!(id), do: Repo.get!(FormulaAlias, id)

  def get_by_name(name), do: Repo.get_by(FormulaAlias, name: name)

  def create_formula_alias(attrs) do
    %FormulaAlias{}
    |> FormulaAlias.changeset(attrs)
    |> Repo.insert()
  end

  def update_formula_alias(%FormulaAlias{} = formula_alias, attrs) do
    formula_alias
    |> FormulaAlias.changeset(attrs)
    |> Repo.update()
  end

  def delete_formula_alias(%FormulaAlias{} = formula_alias) do
    Repo.delete(formula_alias)
  end

  def change_formula_alias(%FormulaAlias{} = formula_alias, attrs \\ %{}) do
    FormulaAlias.changeset(formula_alias, attrs)
  end

  def all_names do
    Repo.all(from fa in FormulaAlias, select: fa.name, order_by: fa.name)
  end
end
