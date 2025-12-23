defmodule GameWeb.FormulaEditorComponentTest do
  use GameWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias GameWeb.FormulaEditorComponent

  defp get_result_json(view) do
    html = render(view)
    # Extract JSON from the <pre id="result-json"> tag
    [json] = Regex.run(~r/<pre id="result-json"[^>]*>(.*?)<\/pre>/, html, capture: :all_but_first)
    # Decode HTML entities
    decoded_json =
      json
      |> String.replace("&quot;", "\"")
      |> String.replace("&amp;", "&")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")

    Jason.decode!(decoded_json)
  end

  describe "FormulaEditor.list_available_keywords/0" do
    test "returns list of available operators" do
      keywords = FormulaEditorComponent.list_available_keywords()

      assert is_list(keywords)
      assert "var" in keywords
      assert "==" in keywords
      assert "and" in keywords
      assert ">" in keywords
      assert "+" in keywords
    end

    test "all keywords have metadata" do
      keywords = FormulaEditorComponent.list_available_keywords()

      Enum.each(keywords, fn keyword ->
        metadata = Game.Formula.operator_metadata(keyword)
        assert is_map(metadata)
        assert Map.has_key?(metadata, :description)
        assert Map.has_key?(metadata, :arity)
      end)
    end
  end

  describe "handle_event/3 with browser-style params" do
    test "handles browser form event for change_operator", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Simulate browser-style form event with nested params structure
      # This is what Phoenix sends when a form field changes in the browser
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{
        "_target" => ["formula", "operator"],
        "formula" => %{"operator" => ">="}
      })

      # Should successfully update the formula without crashing
      html = render(view)
      # >= is HTML-escaped as &gt;=
      assert html =~ "&gt;="

      # Submit and verify the operator was set correctly
      view
      |> form("form", formula: %{"0" => %{"value" => "10"}, "1" => %{"value" => "5"}})
      |> render_submit()

      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{">=" => [10, 5]}
    end
  end

  describe "recursive expression tree UI" do
    test "shows convert to formula button on simple values", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select > operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => ">"})

      html = render(view)
      # Should show the ƒx button to convert simple values to formulas
      assert html =~ "ƒx"
      assert html =~ "Convert to formula"
    end

    test "allows converting simple value to nested formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Set up a simple comparison
      send(view.pid, {:formula_updated, [], %{">" => [5, 10]}})

      # Convert first argument to a formula by clicking the ƒx button
      # This sends a convert_to_formula event
      send(view.pid, {:formula_updated, [0], %{}})

      html = render(view)
      # Should now show an operator dropdown for the first argument
      assert html =~ "formula[0][operator]"
    end

    test "allows converting nested formula back to simple value", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Set up a nested formula
      send(view.pid, {:formula_updated, [], %{">" => [%{"var" => ["hp"]}, 10]}})

      html = render(view)
      # Should show the "123" button to convert back to simple value
      assert html =~ "123"
      assert html =~ "Convert to simple value"

      # Convert back to simple value
      send(view.pid, {:formula_updated, [0], ""})

      html = render(view)
      # Should now show a simple text input instead of nested formula
      assert html =~ "formula[0][value]"
    end
  end

  describe "FormulaEditor component rendering" do
    test "renders with empty formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      assert has_element?(view, "select[name='formula[operator]']")
      assert has_element?(view, "option", "-- Select operator --")
    end

    test "shows all available operators in dropdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      keywords = FormulaEditorComponent.list_available_keywords()

      Enum.each(keywords, fn keyword ->
        assert has_element?(view, "option[value='#{keyword}']")
      end)
    end

    test "renders with existing simple formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Simulate having a formula already set
      send(view.pid, {:formula_updated, [], %{"var" => "hp"}})

      html = render(view)
      assert html =~ "var"
    end
  end

  describe "simple formula editing" do
    test "creates var formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select var operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => "var"})

      # Enter variable name
      view
      |> form("form", formula: %{"0" => %{"value" => "hp"}})
      |> render_change()

      # Submit form
      view
      |> form("form")
      |> render_submit()

      # Check that the formula was saved correctly
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      # var operator takes a single string argument (not a list)
      assert formula == %{"var" => ["hp"]}
    end

    test "creates simple comparison formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select > operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => ">"})

      # Should create default args
      html = render(view)
      assert html =~ ">"

      # Enter values for comparison
      view
      |> form("form",
        formula: %{
          "operator" => ">",
          "0" => %{"value" => "10"},
          "1" => %{"value" => "5"}
        }
      )
      |> render_change()

      view
      |> form("form")
      |> render_submit()

      # Check the formula was saved correctly
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{">" => [10, 5]}
    end

    test "creates logical AND formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select and operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => "and"})

      view
      |> form("form",
        formula: %{
          "operator" => "and",
          "0" => %{"value" => "true"}
        }
      )
      |> render_change()

      # Add another argument
      view
      |> element("button", "+ Add argument")
      |> render_click()

      html = render(view)
      assert html =~ "and"
    end
  end

  describe "nested formula editing" do
    test "creates nested comparison with var", %{conn: conn} do
      # This test verifies that submitting a form with pre-filled nested structure works
      # Note: The UI doesn't provide dropdowns for nested operators, but the parser handles them
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Send a formula_updated message to set up nested structure
      send(view.pid, {:formula_updated, [], %{">" => [%{"var" => ["hp"]}, 5]}})

      # Submit the form
      view
      |> form("form")
      |> render_submit()

      # Should preserve the nested structure
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{">" => [%{"var" => ["hp"]}, 5]}
    end

    test "creates complex nested formula with AND and comparisons", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Send pre-built nested formula via message
      nested_formula = %{
        "and" => [
          %{">" => [%{"var" => ["hp"]}, 0]},
          %{"==" => [%{"var" => ["team"]}, "ally"]}
        ]
      }
      send(view.pid, {:formula_updated, [], nested_formula})

      # Submit the form
      view
      |> form("form")
      |> render_submit()

      # Check that the nested structure was preserved
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == nested_formula
    end
  end

  describe "formula validation" do
    test "generates valid map for simple var", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select var operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => "var"})

      view
      |> form("form",
        formula: %{
          "operator" => "var",
          "0" => %{"value" => "occupied"}
        }
      )
      |> render_submit()

      # Get the result from the page
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{"var" => ["occupied"]}

      # Verify it's a valid formula by resolving it
      result = Game.Formula.resolve(formula, %{"occupied" => true})
      assert result == true
    end

    test "generates valid map for comparison", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select > operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => ">"})

      view
      |> form("form",
        formula: %{
          "operator" => ">",
          "0" => %{"value" => "10"},
          "1" => %{"value" => "5"}
        }
      )
      |> render_submit()

      # Get the result from the page
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{">" => [10, 5]}

      # Verify it's valid
      result = Game.Formula.resolve(formula)
      assert result == true
    end

    test "generates valid map for nested formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Send pre-built nested formula
      nested_formula = %{"<" => [%{"var" => ["hp"]}, %{"var" => ["max_hp"]}]}
      send(view.pid, {:formula_updated, [], nested_formula})

      view
      |> form("form")
      |> render_submit()

      # Get the result from the page
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{"<" => [%{"var" => ["hp"]}, %{"var" => ["max_hp"]}]}

      # Verify it's valid
      result = Game.Formula.resolve(formula, %{"hp" => 5, "max_hp" => 10})
      assert result == true
    end

    test "generates valid map for complex nested AND formula", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Send pre-built nested formula
      nested_formula = %{
        "and" => [
          %{"var" => ["occupied"]},
          %{"==" => [%{"var" => ["team"]}, "ally"]}
        ]
      }
      send(view.pid, {:formula_updated, [], nested_formula})

      view
      |> form("form")
      |> render_submit()

      # Get the result from the page
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)

      assert formula == nested_formula

      # Verify it's valid - should return true when both conditions are true
      result = Game.Formula.resolve(formula, %{"occupied" => true, "team" => "ally"})
      assert result == true

      # Should return false when one condition is false
      result = Game.Formula.resolve(formula, %{"occupied" => true, "team" => "enemy"})
      assert result == false
    end
  end

  describe "type coercion" do
    test "parses integers correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select + operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => "+"})

      # Add second argument
      view
      |> element("button", "+ Add argument")
      |> render_click()

      view
      |> form("form",
        formula: %{
          "operator" => "+",
          "0" => %{"value" => "10"},
          "1" => %{"value" => "20"}
        }
      )
      |> render_submit()

      # Get the result from the page
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{"+" => [10, 20]}

      result = Game.Formula.resolve(formula)
      assert result == 30
    end

    test "parses floats correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Select / operator
      view
      |> element("select[name='formula[operator]']")
      |> render_change(%{"value" => "/"})

      view
      |> form("form",
        formula: %{
          "operator" => "/",
          "0" => %{"value" => "5.5"},
          "1" => %{"value" => "2.0"}
        }
      )
      |> render_submit()

      # Get the result from the page
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{"/" => [5.5, 2.0]}

      result = Game.Formula.resolve(formula)
      assert result == 2.75
    end

    test "keeps strings as strings", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/formula-editor-test")

      # Send pre-built nested formula
      nested_formula = %{"==" => [%{"var" => ["name"]}, "Hero"]}
      send(view.pid, {:formula_updated, [], nested_formula})

      view
      |> form("form")
      |> render_submit()

      # Get the result from the page
      assert has_element?(view, "#result-json")
      formula = get_result_json(view)
      assert formula == %{"==" => [%{"var" => ["name"]}, "Hero"]}

      result = Game.Formula.resolve(formula, %{"name" => "Hero"})
      assert result == true
    end
  end
end
