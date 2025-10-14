defmodule Game.DataTest do
  use Game.DataCase

  alias Game.Data

  describe "characters" do
    alias Game.Data.Character

    import Game.DataFixtures

    @invalid_attrs %{}

    test "list_characters/0 returns all characters" do
      character = character_fixture()
      assert Data.list_characters() == [character]
    end

    test "get_character!/1 returns the character with given id" do
      character = character_fixture()
      assert Data.get_character!(character.id) == character
    end

    test "create_character/1 with valid data creates a character" do
      valid_attrs = %{}

      assert {:ok, %Character{} = character} = Data.create_character(valid_attrs)
    end

    test "create_character/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Data.create_character(@invalid_attrs)
    end

    test "update_character/2 with valid data updates the character" do
      character = character_fixture()
      update_attrs = %{}

      assert {:ok, %Character{} = character} = Data.update_character(character, update_attrs)
    end

    test "update_character/2 with invalid data returns error changeset" do
      character = character_fixture()
      assert {:error, %Ecto.Changeset{}} = Data.update_character(character, @invalid_attrs)
      assert character == Data.get_character!(character.id)
    end

    test "delete_character/1 deletes the character" do
      character = character_fixture()
      assert {:ok, %Character{}} = Data.delete_character(character)
      assert_raise Ecto.NoResultsError, fn -> Data.get_character!(character.id) end
    end

    test "change_character/1 returns a character changeset" do
      character = character_fixture()
      assert %Ecto.Changeset{} = Data.change_character(character)
    end
  end

  describe "characters" do
    alias Game.Data.Character

    import Game.DataFixtures

    @invalid_attrs %{class: nil, base_hp: nil, base_ap: nil, base_movement: nil}

    test "list_characters/0 returns all characters" do
      character = character_fixture()
      assert Data.list_characters() == [character]
    end

    test "get_character!/1 returns the character with given id" do
      character = character_fixture()
      assert Data.get_character!(character.id) == character
    end

    test "create_character/1 with valid data creates a character" do
      valid_attrs = %{class: "some class", base_hp: 42, base_ap: 42, base_movement: 42}

      assert {:ok, %Character{} = character} = Data.create_character(valid_attrs)
      assert character.class == "some class"
      assert character.base_hp == 42
      assert character.base_ap == 42
      assert character.base_movement == 42
    end

    test "create_character/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Data.create_character(@invalid_attrs)
    end

    test "update_character/2 with valid data updates the character" do
      character = character_fixture()
      update_attrs = %{class: "some updated class", base_hp: 43, base_ap: 43, base_movement: 43}

      assert {:ok, %Character{} = character} = Data.update_character(character, update_attrs)
      assert character.class == "some updated class"
      assert character.base_hp == 43
      assert character.base_ap == 43
      assert character.base_movement == 43
    end

    test "update_character/2 with invalid data returns error changeset" do
      character = character_fixture()
      assert {:error, %Ecto.Changeset{}} = Data.update_character(character, @invalid_attrs)
      assert character == Data.get_character!(character.id)
    end

    test "delete_character/1 deletes the character" do
      character = character_fixture()
      assert {:ok, %Character{}} = Data.delete_character(character)
      assert_raise Ecto.NoResultsError, fn -> Data.get_character!(character.id) end
    end

    test "change_character/1 returns a character changeset" do
      character = character_fixture()
      assert %Ecto.Changeset{} = Data.change_character(character)
    end
  end
end
