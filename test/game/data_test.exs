defmodule Game.ContentTest do
  use Game.ContentCase

  alias Game.Content

  describe "base_classes" do
    alias Game.Content.BaseClass

    import Game.ContentFixtures

    @invalid_attrs %{}

    test "list_base_classes/0 returns all base_classes" do
      base_class = base_class_fixture()
      assert Content.list_base_classes() == [base_class]
    end

    test "get_base_class!/1 returns the base_class with given id" do
      base_class = base_class_fixture()
      assert Content.get_base_class!(base_class.id) == base_class
    end

    test "create_base_class/1 with valid data creates a base_class" do
      valid_attrs = %{}

      assert {:ok, %BaseClass{} = base_class} = Content.create_base_class(valid_attrs)
    end

    test "create_base_class/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_base_class(@invalid_attrs)
    end

    test "update_base_class/2 with valid data updates the base_class" do
      base_class = base_class_fixture()
      update_attrs = %{}

      assert {:ok, %BaseClass{} = base_class} =
               Content.update_base_class(base_class, update_attrs)
    end

    test "update_base_class/2 with invalid data returns error changeset" do
      base_class = base_class_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_base_class(base_class, @invalid_attrs)
      assert base_class == Content.get_base_class!(base_class.id)
    end

    test "delete_base_class/1 deletes the base_class" do
      base_class = base_class_fixture()
      assert {:ok, %BaseClass{}} = Content.delete_base_class(base_class)
      assert_raise Ecto.NoResultsError, fn -> Content.get_base_class!(base_class.id) end
    end

    test "change_base_class/1 returns a base_class changeset" do
      base_class = base_class_fixture()
      assert %Ecto.Changeset{} = Content.change_base_class(base_class)
    end
  end

  describe "base_classes" do
    alias Game.Content.BaseClass

    import Game.ContentFixtures

    @invalid_attrs %{class: nil, base_hp: nil, base_ap: nil, base_movement: nil}

    test "list_base_classes/0 returns all base_classes" do
      base_class = base_class_fixture()
      assert Content.list_base_classes() == [base_class]
    end

    test "get_base_class!/1 returns the base_class with given id" do
      base_class = base_class_fixture()
      assert Content.get_base_class!(base_class.id) == base_class
    end

    test "create_base_class/1 with valid data creates a base_class" do
      valid_attrs = %{class: "some class", base_hp: 42, base_ap: 42, base_movement: 42}

      assert {:ok, %BaseClass{} = base_class} = Content.create_base_class(valid_attrs)
      assert base_class.class == "some class"
      assert base_class.base_hp == 42
      assert base_class.base_ap == 42
      assert base_class.base_movement == 42
    end

    test "create_base_class/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_base_class(@invalid_attrs)
    end

    test "update_base_class/2 with valid data updates the base_class" do
      base_class = base_class_fixture()
      update_attrs = %{class: "some updated class", base_hp: 43, base_ap: 43, base_movement: 43}

      assert {:ok, %BaseClass{} = base_class} =
               Content.update_base_class(base_class, update_attrs)

      assert base_class.class == "some updated class"
      assert base_class.base_hp == 43
      assert base_class.base_ap == 43
      assert base_class.base_movement == 43
    end

    test "update_base_class/2 with invalid data returns error changeset" do
      base_class = base_class_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_base_class(base_class, @invalid_attrs)
      assert base_class == Content.get_base_class!(base_class.id)
    end

    test "delete_base_class/1 deletes the base_class" do
      base_class = base_class_fixture()
      assert {:ok, %BaseClass{}} = Content.delete_base_class(base_class)
      assert_raise Ecto.NoResultsError, fn -> Content.get_base_class!(base_class.id) end
    end

    test "change_base_class/1 returns a base_class changeset" do
      base_class = base_class_fixture()
      assert %Ecto.Changeset{} = Content.change_base_class(base_class)
    end
  end
end
