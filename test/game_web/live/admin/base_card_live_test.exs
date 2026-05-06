defmodule GameWeb.Admin.BaseCardLiveTest do
  use GameWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Game.BaseCards
  alias Game.{Card, Character, CombatState, Grid, Fixtures}

  setup :register_and_log_in_admin

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

  # Selector for the root operator dropdown of effect N's "value" param formula editor.
  # With EffectField, value is now nested under change[effects][N][value][value][operator].
  defp effect_operator_select(view, effect_index) do
    element(view, "select[name='change[effects][#{effect_index}][value][value][operator]']")
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
      assert html =~ ~s(name="change[effects][0][value][value][0][value]")
    end

    test "clicking add argument appends a new input slot", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # Switch to + operator first (has variable arity, starts with 1 arg)
      effect_operator_select(view, 0) |> render_change(%{"value" => "+"})

      html_before = render(view)
      # Count value inputs at depth 0 of effect 0's formula (now under [value][value])
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

    test "selecting an operator on a nested arg node does not crash", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # Set root to * (gives two literal arg slots with a ƒx button each)
      view
      |> element("select[name='change[effects][0][value][value][operator]']")
      |> render_change(%{
        "change" => %{"effects" => %{"0" => %{"value" => %{"value" => %{"operator" => "*"}}}}},
        "_target" => ["change", "effects", "0", "value", "value", "operator"]
      })

      # Convert the first literal arg into a nested formula node via its ƒx button
      view
      |> element("button[phx-click='convert_to_formula'][phx-value-path='[0]']")
      |> render_click()

      # Now a child operator select exists for the nested arg — select var on it
      view
      |> element("select[name='change[effects][0][value][value][0][operator]']")
      |> render_change(%{
        "change" => %{
          "effects" => %{"0" => %{"value" => %{"value" => %{"0" => %{"operator" => "var"}}}}}
        },
        "_target" => ["change", "effects", "0", "value", "value", "0", "operator"]
      })

      html = render(view)

      # var node's text input should appear, and the root * operator must not be wiped
      assert html =~ ~s(name="change[effects][0][value][value][0][0][value]")
      assert html =~ ~s(name="change[effects][0][value][value][operator]")
    end

    test "clicking ƒx converts a literal arg to a nested formula node", %{conn: conn, card: card} do
      {:ok, view, _html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # The literal `3` arg has a convert_to_formula button
      assert has_element?(view, "button[phx-click='convert_to_formula']")

      # Target the ƒx button inside the value formula editor specifically
      view
      |> element("button[phx-click='convert_to_formula'][phx-value-path='[1]']")
      |> render_click()

      html = render(view)
      # A nested operator select should now appear where the literal was
      # The literal `3` input should be replaced by a nested [operator] select
      assert html =~ "[value][value][1][operator]"
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
      # With EffectField, the submitted value is keyed by param name.
      # damage effect has params ["value"], so it submits as value: %{"value" => formula_params}.
      # parse_effect_value flattens single-param maps to the scalar formula directly.
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
                "value" => %{
                  "operator" => "+",
                  "0" => %{"value" => "5"},
                  "1" => %{"value" => "3"}
                }
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

  describe "formula editor for new effects" do
    test "selecting an operator shows the correct number of operand slots", %{conn: conn} do
      # Start with a card whose effect has an empty formula value — this is the
      # "clean slate" state a user reaches after adding a new effect row.
      {:ok, card} =
        Game.BaseCards.create_base_card(%{
          name: "New Effect Card",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "damage", value: %{}}]
        })

      {:ok, view, html} = live(conn, ~p"/admin/base_cards/#{card.id}/edit")

      # On load the formula editor shows no operator selected and no operand slots
      refute html =~ ~s(name="change[effects][0][value][value][0][value]")

      # Simulate what the browser actually sends when a user picks an option.
      # With EffectField the "value" param editor field is nested under [value][value].
      view
      |> element("select[name='change[effects][0][value][value][operator]']")
      |> render_change(%{
        "change" => %{"effects" => %{"0" => %{"value" => %{"value" => %{"operator" => "*"}}}}},
        "_target" => ["change", "effects", "0", "value", "value", "operator"]
      })

      html = render(view)

      # Two operand slots must now appear below the operator
      assert html =~ ~s(name="change[effects][0][value][value][0][value]"),
             "expected first operand slot after selecting * operator"

      assert html =~ ~s(name="change[effects][0][value][value][1][value]"),
             "expected second operand slot after selecting * operator"
    end
  end

  describe "creating cards with new compound effects via admin form" do
    # Builds a minimal valid form params map for a card with the given effects list.
    # Each effect is %{"type" => "...", params: %{"param_key" => "scalar_value", ...}}.
    # With EffectField, all params are submitted under "value" as a map keyed by param name,
    # where each value is a formula params map (literal mode: %{"value" => "3"}).
    defp card_form_params(name, effects) do
      indexed_effects =
        effects
        |> Enum.with_index()
        |> Map.new(fn {effect, idx} ->
          {type, params} = Map.pop(effect, "type")

          # Wrap each param value in the literal formula format %{"value" => v}
          wrapped_params =
            Map.new(params, fn
              {k, ""} -> {k, %{}}
              {k, v} -> {k, %{"value" => v}}
            end)

          {to_string(idx), %{"type" => type, "value" => wrapped_params}}
        end)

      %{
        "change" => %{
          "name" => name,
          "ap" => "1",
          "headline" => "test",
          "rarity" => "common",
          "effects" => indexed_effects,
          "effects_order" => Enum.map(0..(length(effects) - 1), &to_string/1)
        }
      }
    end

    test "EffectField renders param inputs based on effect type", %{conn: conn} do
      # A "dot" effect has params ["value", "damage"] — both should get formula editors
      {:ok, dot_card} =
        BaseCards.create_base_card(%{
          name: "Dot Render Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "dot", value: %{"value" => 3, "damage" => 5}}]
        })

      {:ok, _view, html} = live(conn, ~p"/admin/base_cards/#{dot_card.id}/edit")

      # "value" and "damage" param editors are rendered (each has a literal value input)
      assert html =~ ~s(name="change[effects][0][value][value][value]")
      assert html =~ ~s(name="change[effects][0][value][damage][value]")

      # A "move" effect has params ["angle", "distance"] — two formula editors
      {:ok, move_card} =
        BaseCards.create_base_card(%{
          name: "Move Render Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "move", value: %{"angle" => 0, "distance" => 1}}]
        })

      {:ok, _view, html} = live(conn, ~p"/admin/base_cards/#{move_card.id}/edit")

      assert html =~ ~s(name="change[effects][0][value][angle][value]")
      assert html =~ ~s(name="change[effects][0][value][distance][value]")

      # A "damage" effect has params ["value"] only — no extra inputs
      {:ok, dmg_card} =
        BaseCards.create_base_card(%{
          name: "Damage Render Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "damage", value: 5}]
        })

      {:ok, _view, html} = live(conn, ~p"/admin/base_cards/#{dmg_card.id}/edit")

      assert html =~ ~s(name="change[effects][0][value][value][value]")
      refute html =~ ~s(name="change[effects][0][value][damage][value]")
    end

    test "saves stuck effect and can apply it in combat", %{conn: conn} do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Stuck Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "stuck", value: 1}]
        })

      {:ok, view, _} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      view
      |> form(
        "#resource-form",
        card_form_params("Stuck Test", [
          %{"type" => "stuck", "value" => "2"}
        ])
      )
      |> render_submit(%{"save-type" => "save"})

      # parse_effect_value flattens single-param maps: %{"value" => 2} → 2

      reloaded = BaseCards.get_base_card!(card_db.id)
      [effect] = reloaded.effects
      assert effect.type == "stuck"
      assert effect.value == "2"

      # Verify combat: stuck character cannot move
      card = %Game.Card{
        id: 1,
        name: "Stuck",
        cost: 0,
        range: 2,
        effects: reloaded.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()
      mage = %{Fixtures.mage() | position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage},
          {2, 0, -2} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :stuck) != nil
    end

    test "saves slow effect with duration and can apply it in combat", %{conn: conn} do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Slow Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "slow", value: %{"value" => 1, "duration" => 1}}]
        })

      {:ok, view, _} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      view
      |> form(
        "#resource-form",
        card_form_params("Slow Test", [
          %{"type" => "slow", "value" => "1", "duration" => "3"}
        ])
      )
      |> render_submit(%{"save-type" => "save"})

      reloaded = BaseCards.get_base_card!(card_db.id)
      [effect] = reloaded.effects
      assert effect.type == "slow"
      # value is a multi-param map: %{"value" => 1, "duration" => 3}
      assert effect.value == %{"value" => 1, "duration" => 3}

      card = %Game.Card{
        id: 2,
        name: "Slow",
        cost: 0,
        range: 2,
        effects: reloaded.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()
      mage = %{Fixtures.mage() | position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      slow = Character.get_status_effect(updated_mage, :slow)
      assert slow != nil
      assert slow.value == 1
      assert slow.duration == 3
    end

    test "saves stun effect and can apply it in combat", %{conn: conn} do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Stun Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "stun", value: 1}]
        })

      {:ok, view, _} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      view
      |> form(
        "#resource-form",
        card_form_params("Stun Test", [
          %{"type" => "stun", "value" => "2"}
        ])
      )
      |> render_submit(%{"save-type" => "save"})

      reloaded = BaseCards.get_base_card!(card_db.id)
      [effect] = reloaded.effects
      assert effect.type == "stun"

      card = %Game.Card{
        id: 3,
        name: "Stun",
        cost: 0,
        range: 2,
        effects: reloaded.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()
      mage = %{Fixtures.mage() | position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :stun) != nil
    end

    test "saves dot effect with damage/turn and can apply it in combat", %{conn: conn} do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "DoT Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "dot", value: %{"value" => 1, "damage" => 1}}]
        })

      {:ok, view, _} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      view
      |> form(
        "#resource-form",
        card_form_params("DoT Test", [
          %{"type" => "dot", "value" => "3", "damage" => "5"}
        ])
      )
      |> render_submit(%{"save-type" => "save"})

      reloaded = BaseCards.get_base_card!(card_db.id)
      [effect] = reloaded.effects
      assert effect.type == "dot"
      assert effect.value == %{"value" => 3, "damage" => 5}

      card = %Game.Card{
        id: 4,
        name: "DoT",
        cost: 0,
        range: 2,
        effects: reloaded.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()
      mage = %{Fixtures.mage() | position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      dot = Character.get_status_effect(updated_mage, :dot)
      assert dot != nil
      assert dot.damage == 5
      assert dot.value == 3
    end

    test "saves regen effect with heal/turn and can apply it in combat", %{conn: conn} do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Regen Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "regen", value: %{"value" => 1, "heal" => 1}}]
        })

      {:ok, view, _} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      view
      |> form(
        "#resource-form",
        card_form_params("Regen Test", [
          %{"type" => "regen", "value" => "3", "heal" => "4"}
        ])
      )
      |> render_submit(%{"save-type" => "save"})

      reloaded = BaseCards.get_base_card!(card_db.id)
      [effect] = reloaded.effects
      assert effect.type == "regen"
      assert effect.value == %{"value" => 3, "heal" => 4}

      card = %Game.Card{
        id: 5,
        name: "Regen",
        cost: 0,
        range: 2,
        effects: reloaded.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()
      mage = %{Fixtures.mage() | hp: 10, position: {1, 0, -1}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      regen = Character.get_status_effect(updated_mage, :regen)
      assert regen != nil
      assert regen.heal == 4
      assert regen.value == 3
    end

    test "saves cleanse effect and can apply it in combat", %{conn: conn} do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Cleanse Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "cleanse"}]
        })

      {:ok, view, _} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      view
      |> form(
        "#resource-form",
        card_form_params("Cleanse Test", [
          %{"type" => "cleanse", "value" => ""}
        ])
      )
      |> render_submit(%{"save-type" => "save"})

      reloaded = BaseCards.get_base_card!(card_db.id)
      [effect] = reloaded.effects
      assert effect.type == "cleanse"

      card = %Game.Card{
        id: 6,
        name: "Cleanse",
        cost: 0,
        range: 2,
        effects: reloaded.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()

      mage =
        Fixtures.mage()
        |> Map.put(:position, {1, 0, -1})
        |> Character.add_status_effect(%{type: :stun, value: 2})
        |> Character.add_status_effect(%{type: :dot, damage: 5, value: 2})

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert Character.get_status_effect(updated_mage, :stun) == nil
      assert Character.get_status_effect(updated_mage, :dot) == nil
    end

    test "saves ethereal effect and can apply it in combat", %{conn: conn} do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Ethereal Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "ethereal", value: 1}]
        })

      {:ok, view, _} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      view
      |> form(
        "#resource-form",
        card_form_params("Ethereal Test", [
          %{"type" => "ethereal", "value" => "2"}
        ])
      )
      |> render_submit(%{"save-type" => "save"})

      reloaded = BaseCards.get_base_card!(card_db.id)
      [effect] = reloaded.effects
      assert effect.type == "ethereal"

      card = %Game.Card{
        id: 7,
        name: "Ethereal",
        cost: 0,
        range: 0,
        effects: reloaded.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter]},
        queue: [],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, fighter, card)
      ethereal = Character.get_status_effect(updated.current_turn.player, :ethereal)
      assert ethereal != nil
      assert ethereal.value == 3
    end

    test "pull card with var formula is stored and applies pull-toward-caster in combat", %{
      conn: conn
    } do
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Pull Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [
            %{type: "move", value: %{"angle" => %{"var" => "angle_toward_caster"}, "distance" => 1}}
          ]
        })

      # Admin edit page loads without crashing (smoke test)
      {:ok, _view, _html} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      [effect] = card_db.effects
      assert effect.type == "move"
      assert effect.value == %{"angle" => %{"var" => "angle_toward_caster"}, "distance" => 1}

      card = %Game.Card{
        id: 9,
        name: "Pull",
        cost: 1,
        range: 2,
        effects: card_db.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()
      # mage at {2,0,-2}; fighter (caster) at {0,0,0}
      # direction from mage toward fighter is {-1,0,1}, so mage moves to {1,0,-1}
      mage = %{Fixtures.mage() | position: {2, 0, -2}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {1, 0, -1} => %{terrain: :plain, occupied_by: nil},
          {2, 0, -2} => %{terrain: :plain, occupied_by: mage}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {1, 0, -1}
    end

    test "move effect with static delta applies it in combat", %{conn: conn} do
      # Move params are ["value"]; a static delta is stored as a q/r/s map directly.
      # The admin page loads without crashing (smoke test).
      {:ok, card_db} =
        BaseCards.create_base_card(%{
          name: "Move Test",
          ap: 1,
          headline: "test",
          rarity: :common,
          effects: [%{type: "move", value: %{"q" => 1, "r" => 0, "s" => -1}}]
        })

      {:ok, _view, _html} = live(conn, ~p"/admin/base_cards/#{card_db.id}/edit")

      card = %Game.Card{
        id: 8,
        name: "Move",
        cost: 0,
        range: 2,
        effects: card_db.effects,
        targeting: %{"type" => "character"}
      }

      fighter = Fixtures.fighter()
      # mage at {2,0,-2}, pushed by {1,0,-1} → {3,0,-3}
      mage = %{Fixtures.mage() | position: {2, 0, -2}}

      grid = %Grid{
        tiles: %{
          {0, 0, 0} => %{terrain: :plain, occupied_by: fighter},
          {2, 0, -2} => %{terrain: :plain, occupied_by: mage},
          {3, 0, -3} => %{terrain: :plain, occupied_by: nil}
        }
      }

      combat = %CombatState{
        state: :running,
        __constants__: %{players: [fighter, mage]},
        queue: [mage],
        grid: grid,
        current_turn: %{starting_position: fighter.position, player: fighter, card: nil}
      }

      {updated, _anims} = Card.process_card(combat, mage, card)
      updated_mage = Enum.find(updated.queue, &(&1.id == mage.id))
      assert updated_mage.position == {3, 0, -3}
    end
  end

  # Count value-type inputs at depth 0 of effect N's "value" param formula
  defp count_value_inputs(html, effect_index) do
    prefix = "change[effects][#{effect_index}][value][value]"

    ~r/name="#{Regex.escape(prefix)}\[(\d+)\]\[value\]"/
    |> Regex.scan(html)
    |> length()
  end
end
