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
      |> Enum.into(%{})
      |> Game.Data.create_character()

    character
  end

  @doc """
  Generate a character.
  """
  def character_fixture(attrs \\ %{}) do
    {:ok, character} =
      attrs
      |> Enum.into(%{
        base_ap: 42,
        base_hp: 42,
        base_movement: 42,
        class: "some class"
      })
      |> Game.Data.create_character()

    character
  end
end
