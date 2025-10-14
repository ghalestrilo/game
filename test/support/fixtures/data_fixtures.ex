defmodule Game.DataFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Game.Data` context.
  """

  @doc """
  Generate a character.
  """
  def character_fixture(attrs \\ %{}) do
    {:ok, character} =
      attrs
      |> Enum.into(%{

      })
      |> Game.Data.create_character()

    character
  end
end
