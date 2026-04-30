defmodule Game.Content do
  @moduledoc """
  The Data context.
  """

  import Ecto.Query, warn: false
  alias Game.Repo

  alias Game.Content.BaseClass
  alias Game.BaseDecks.BaseDeck

  @doc """
  Returns the list of base_classes.

  ## Examples

      iex> list_base_classes()
      [%BaseClass{}, ...]

  """
  def list_base_classes do
    Repo.all(BaseClass)
  end

  @doc """
  Gets a single base_class.

  Raises `Ecto.NoResultsError` if the BaseClass does not exist.

  ## Examples

      iex> get_base_class!(123)
      %BaseClass{}

      iex> get_base_class!(456)
      ** (Ecto.NoResultsError)

  """
  def get_base_class!(id), do: Repo.get!(BaseClass, id)

  def get_base_class_by_class!(class),
    do:
      BaseClass
      |> Repo.get_by!([class: class], preload: [:deck])
      |> Repo.preload(deck: [:cards], strategy: [])

  @doc """
  Creates a base_class.

  ## Examples

      iex> create_base_class(%{field: value})
      {:ok, %BaseClass{}}

      iex> create_base_class(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_base_class(attrs \\ %{}) do
    %BaseClass{}
    |> BaseClass.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a base_class.

  ## Examples

      iex> update_base_class(base_class, %{field: new_value})
      {:ok, %BaseClass{}}

      iex> update_base_class(base_class, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_base_class(%BaseClass{} = base_class, attrs) do
    base_class
    |> BaseClass.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a base_class.

  ## Examples

      iex> delete_base_class(base_class)
      {:ok, %BaseClass{}}

      iex> delete_base_class(base_class)
      {:error, %Ecto.Changeset{}}

  """
  def delete_base_class(%BaseClass{} = base_class) do
    Repo.delete(base_class)
  end

  @doc """
  Returns the list of decks.

  ## Examples

      iex> list_decks()
      [%Deck{}, ...]

  """
  def list_decks do
    Repo.all(BaseDeck)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking base_class changes.

  ## Examples

      iex> change_base_class(base_class)
      %Ecto.Changeset{data: %BaseClass{}}

  """
  def change_base_class(%BaseClass{} = base_class, attrs \\ %{}) do
    BaseClass.changeset(base_class, attrs)
  end
end
