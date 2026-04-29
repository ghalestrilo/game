defmodule GameWeb.Admin.BaseCardLiveTest do
  use GameWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Game.BaseCards

  setup do
    {:ok, card} =
      BaseCards.create_base_card(%{
        name: "Test Card",
        ap: 2,
        headline: "A test card",
        rarity: :common,
        effects: [%{type: "damage", value: %{"*" => [%{"var" => "caster.ap"}, 3]}}]
      })

    %{card: card}
  end

  # Selector for the root operator dropdown of effect N's formula editor
  defp effect_operator_select(view, effect_index) do
    element(view, "select[name='change[effects][#{effect_index}][value][operator]']")
  end

  defp add_arg_button(view, _effect_index) do
    element(view, "button[phx-click='add_arg']")
  end

  describe "formula editor in effects" do
    test "renders existing formula as a tree", %{conn: conn, card: card} do
      {:ok, _view, html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # The existing formula %{"*" => [%{"var" => "caster.ap"}, 3]} should render:
      # - The * operator selected
      # - A nested var node showing the variable name input with "caster.ap"
      # - A literal value input with "3"
      assert html =~ ~s(value="caster.ap")
      assert html =~ ~s(value="3")
    end

    test "changing operator on root formula updates the tree", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # Change the root operator from * to +
      effect_operator_select(view, 0)
      |> render_change(%{"value" => "+"})

      html = render(view)

      # The + operator should now be selected (shown as selected option)
      assert html =~ ~s(value="+" selected)
      # The new operator's default args appear as empty inputs
      assert html =~ ~s(name="change[effects][0][value][0][value]")
    end

    test "clicking add argument appends a new input slot", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # Switch to + operator first (has variable arity, starts with 1 arg)
      effect_operator_select(view, 0) |> render_change(%{"value" => "+"})

      html_before = render(view)
      # Count value inputs at depth 0 of effect 0's formula
      before_count = count_value_inputs(html_before, 0)

      # Click the root formula's add argument button
      view
      |> element("button[phx-click='add_arg']")
      |> render_click()

      html_after = render(view)
      assert count_value_inputs(html_after, 0) == before_count + 1
    end

    test "clicking remove on a nested node removes it from the tree", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # The existing formula has a nested var node with caster.ap
      assert has_element?(view, "button[phx-click='remove_node']")

      view
      |> element("button[phx-click='remove_node']")
      |> render_click()

      html = render(view)
      # The var node for caster.ap should be gone
      refute html =~ ~s(value="caster.ap")
    end

    test "clicking ƒx converts a literal arg to a nested formula node", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # The literal `3` arg has a convert_to_formula button
      assert has_element?(view, "button[phx-click='convert_to_formula']")

      view
      |> element("button[phx-click='convert_to_formula']")
      |> render_click()

      html = render(view)
      # A nested operator select should now appear where the literal was
      # The literal `3` input should be replaced by a nested [operator] select
      assert html =~ "[value][1][operator]"
    end

    test "saving a card with formula effect persists the formula correctly", %{
      conn: conn,
      card: card
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # First change to a simple + operator (two literal args) via user interaction
      effect_operator_select(view, 0) |> render_change(%{"value" => "+"})
      add_arg_button(view, 0) |> render_click()

      # Now the form has change[effects][0][value][0][value] and [1][value] inputs
      view
      |> form("#resource-form", %{
        "change" => %{
          "name" => card.name,
          "ap" => to_string(card.ap),
          "headline" => card.headline,
          "rarity" => "common",
          "effects" => %{
            "0" => %{
              "type" => "damage",
              "value" => %{
                "operator" => "+",
                "0" => %{"value" => "5"},
                "1" => %{"value" => "3"}
              }
            }
          },
          "effects_order" => ["0"]
        }
      })
      |> render_submit(%{"save-type" => "save"})

      reloaded = BaseCards.get_base_card!(card.id)
      [effect] = reloaded.effects
      assert effect.value == %{"+" => [5, 3]}
    end
  end

  # Count value-type inputs at depth 0 of effect N's formula
  defp count_value_inputs(html, effect_index) do
    prefix = "change[effects][#{effect_index}][value]"

    ~r/name="#{Regex.escape(prefix)}\[(\d+)\]\[value\]"/
    |> Regex.scan(html)
    |> length()
  end
end
