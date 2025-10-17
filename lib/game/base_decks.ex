defmodule Game.BaseDecks do
  @moduledoc """
  The BaseDecks context.
  """

  import Ecto.Query, warn: false
  alias Game.Repo

  alias Game.BaseDecks.BaseDeck

  @doc """
  Returns the list of basedecks.

  ## Examples

      iex> list_basedecks()
      [%BaseDeck{}, ...]

  """
  def list_basedecks do
    Repo.all(BaseDeck)
  end

  @doc """
  Gets a single base_deck.

  Raises `Ecto.NoResultsError` if the Base deck does not exist.

  ## Examples

      iex> get_base_deck!(123)
      %BaseDeck{}

      iex> get_base_deck!(456)
      ** (Ecto.NoResultsError)

  """
  def get_base_deck!(id) do
    BaseDeck
    |> Repo.get!(id)
    |> Repo.preload([:base_deck_cards, :cards])
  end

  @doc """
  Creates a base_deck.

  ## Examples

      iex> create_base_deck(%{field: value})
      {:ok, %BaseDeck{}}

      iex> create_base_deck(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_base_deck(attrs \\ %{}) do
    %BaseDeck{}
    |> BaseDeck.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a base_deck.

  ## Examples

      iex> update_base_deck(base_deck, %{field: new_value})
      {:ok, %BaseDeck{}}

      iex> update_base_deck(base_deck, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_base_deck(%BaseDeck{} = base_deck, attrs) do
    base_deck
    |> BaseDeck.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a base_deck.

  ## Examples

      iex> delete_base_deck(base_deck)
      {:ok, %BaseDeck{}}

      iex> delete_base_deck(base_deck)
      {:error, %Ecto.Changeset{}}

  """
  def delete_base_deck(%BaseDeck{} = base_deck) do
    Repo.delete(base_deck)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking base_deck changes.

  ## Examples

      iex> change_base_deck(base_deck)
      %Ecto.Changeset{data: %BaseDeck{}}

  """
  def change_base_deck(%BaseDeck{} = base_deck, attrs \\ %{}) do
    BaseDeck.changeset(base_deck, attrs)
  end
end
