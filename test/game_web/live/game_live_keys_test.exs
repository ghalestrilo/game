defmodule GameWeb.GameLiveKeysTest do
  use GameWeb.ConnCase

  import Phoenix.LiveViewTest

  # fixed positions (adjacent) so attack cards reliably reach the opponent
  defp uri, do: ~p"/sandbox?initial_state=[-1_0_1:fighter:1,1_0_-1:mage:2]"

  defp get_assigns(view) do
    :sys.get_state(view.pid).socket.assigns
  end

  defp pick_first_card(view) do
    render_click(view, "pick_card", %{"card_index" => "0"})
  end

  # picks the first card in hand that has at least one valid target; returns the index or nil
  defp pick_card_with_targets(view) do
    assigns = get_assigns(view)
    combat = assigns.game_state.combat
    hand = combat.current_turn.player.cards.hand

    result =
      hand
      |> Enum.with_index()
      |> Enum.find(fn {card, _i} ->
        simulated = put_in(combat.current_turn.card, card)
        keyboard_target_count(simulated) > 0
      end)

    case result do
      {_card, idx} ->
        render_click(view, "pick_card", %{"card_index" => "#{idx}"})
        idx

      nil ->
        nil
    end
  end

  describe "Esc" do
    test "deselects the current card when a card is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      pick_first_card(view)
      assert get_assigns(view).game_state.combat.state == :card_selected

      render_click(view, "handle_keys", %{"key" => "Escape"})
      assert get_assigns(view).game_state.combat.state == :running
    end

    test "is a no-op when no card is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      assert get_assigns(view).game_state.combat.state == :running
      render_click(view, "handle_keys", %{"key" => "Escape"})
      assert get_assigns(view).game_state.combat.state == :running
    end
  end

  describe "ArrowRight / ArrowLeft" do
    test "ArrowRight selects the next card in hand", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      assert get_assigns(view).keyboard_card_index == 0

      render_click(view, "handle_keys", %{"key" => "ArrowRight"})
      assert get_assigns(view).keyboard_card_index == 1
      assert get_assigns(view).game_state.combat.state == :card_selected
    end

    test "ArrowLeft wraps from index 0 to last card", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      hand = get_assigns(view).game_state.combat.current_turn.player.cards.hand
      last_index = length(hand) - 1

      render_click(view, "handle_keys", %{"key" => "ArrowLeft"})
      assert get_assigns(view).keyboard_card_index == last_index
      assert get_assigns(view).game_state.combat.state == :card_selected
    end

    test "ArrowRight wraps from last card back to index 0", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      hand = get_assigns(view).game_state.combat.current_turn.player.cards.hand
      last_index = length(hand) - 1

      # Navigate to last card
      Enum.each(1..last_index, fn _ ->
        render_click(view, "handle_keys", %{"key" => "ArrowRight"})
      end)

      assert get_assigns(view).keyboard_card_index == last_index

      render_click(view, "handle_keys", %{"key" => "ArrowRight"})
      assert get_assigns(view).keyboard_card_index == 0
    end
  end

  describe "ArrowDown / ArrowUp" do
    test "ArrowDown increments keyboard_target_index when a card is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      idx = pick_card_with_targets(view)
      assert idx != nil, "expected at least one card with valid targets"
      assert get_assigns(view).keyboard_target_index == 0

      render_click(view, "handle_keys", %{"key" => "ArrowDown"})
      assert get_assigns(view).keyboard_target_index == 1
    end

    test "ArrowUp wraps keyboard_target_index to last target", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      idx = pick_card_with_targets(view)
      assert idx != nil, "expected at least one card with valid targets"
      combat = get_assigns(view).game_state.combat
      target_count = keyboard_target_count(combat)

      render_click(view, "handle_keys", %{"key" => "ArrowUp"})
      assert get_assigns(view).keyboard_target_index == target_count - 1
    end

    test "ArrowDown is a no-op when no card is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, uri())

      render_click(view, "handle_keys", %{"key" => "ArrowDown"})
      assert get_assigns(view).keyboard_target_index == 0
      assert get_assigns(view).game_state.combat.state == :running
    end
  end

  # mirrors the private keyboard_targets/1 in game_live.ex
  defp keyboard_target_count(combat) do
    card = combat.current_turn.card
    {overlay, _} = Game.Card.build_tile_overlay(card, combat)

    valid_coords =
      overlay |> Enum.filter(&match?({_, :valid}, &1)) |> MapSet.new(fn {coord, _} -> coord end)

    Game.CombatState.get_current_queue(combat)
    |> Enum.with_index()
    |> Enum.filter(fn {character, _i} -> MapSet.member?(valid_coords, character.position) end)
    |> length()
  end
end
