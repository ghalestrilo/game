defmodule Game.BaseCards do
  @moduledoc """
  The BaseCards context.
  """

  import Ecto.Query, warn: false
  alias Game.Repo

  alias Game.BaseCards.BaseCard

  @doc """
  Returns the list of basecards.

  ## Examples

      iex> list_basecards()
      [%BaseCard{}, ...]

  """
  def list_basecards do
    Repo.all(BaseCard)
  end

  @doc """
  Gets a single base_card.

  Raises `Ecto.NoResultsError` if the Base card does not exist.

  ## Examples

      iex> get_base_card!(123)
      %BaseCard{}

      iex> get_base_card!(456)
      ** (Ecto.NoResultsError)

  """
  def get_base_card!(id), do: Repo.get!(BaseCard, id)

  def get_base_card_by_slug!(slug), do: Repo.get_by!(BaseCard, slug: slug)

  @doc """
  Creates a base_card.

  ## Examples

      iex> create_base_card(%{field: value})
      {:ok, %BaseCard{}}

      iex> create_base_card(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_base_card(attrs \\ %{}) do
    %BaseCard{}
    |> BaseCard.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a base_card.

  ## Examples

      iex> update_base_card(base_card, %{field: new_value})
      {:ok, %BaseCard{}}

      iex> update_base_card(base_card, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_base_card(%BaseCard{} = base_card, attrs) do
    base_card
    |> BaseCard.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a base_card.

  ## Examples

      iex> delete_base_card(base_card)
      {:ok, %BaseCard{}}

      iex> delete_base_card(base_card)
      {:error, %Ecto.Changeset{}}

  """
  def delete_base_card(%BaseCard{} = base_card) do
    Repo.delete(base_card)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking base_card changes.

  ## Examples

      iex> change_base_card(base_card)
      %Ecto.Changeset{data: %BaseCard{}}

  """
  def change_base_card(%BaseCard{} = base_card, attrs \\ %{}) do
    BaseCard.changeset(base_card, attrs)
  end
end
