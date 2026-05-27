# Feature: Formula Editor — `var` Autocomplete Input

## Context

The `var` node in the formula editor is currently rendered as a `<select>` populated from
`Formula.available_variables/1`. This hard-coded list has repeatedly needed manual updates when a
variable was known to be available in the serialized context but missing from the list. The select
also gives no way to type a path that isn't in the list.

The fix: replace the `<select>` with a free-text input that shows a filtered dropdown of known
variables as the user types, but also accepts arbitrary input. Users get autocomplete when the
variable is known and a free-form escape hatch when it isn't.

---

## Approach

Pure LiveView — no JS hook required. A `phx-change` on the input sends keystrokes to the
component, which filters `@variables` and re-renders the suggestion list. Clicking a suggestion
or pressing Enter commits the value. The parent form still submits the final value via the same
hidden/text input name, so no changes to the form submission path are needed.

---

## Implementation Plan

### 1. Add autocomplete state to `FormulaEditorComponent`

**File:** `lib/game_web/live/formula_editor_component.ex` — `update/2`

Add two assigns: the current text input value and the filtered suggestion list.

```elixir
socket
|> assign(:var_input, current_var_value(assigns))
|> assign(:var_suggestions, [])
```

`current_var_value/1` extracts the existing value from the formula so the input is pre-populated
when editing an existing node.

### 2. Add a `filter_var` event handler

**File:** `lib/game_web/live/formula_editor_component.ex`

```elixir
def handle_event("filter_var", %{"value" => query, "path" => path_json}, socket) do
  path = Jason.decode!(path_json)
  suggestions =
    if String.length(query) == 0 do
      socket.assigns.variables
    else
      Enum.filter(socket.assigns.variables, fn v ->
        String.contains?(String.downcase(v.name), String.downcase(query))
      end)
    end

  {:noreply, assign(socket, var_input: query, var_suggestions: suggestions, var_active_path: path)}
end
```

`var_active_path` tracks which `var` node is open so multiple `var` nodes on the same form don't
interfere.

### 3. Add a `select_var` event handler

```elixir
def handle_event("select_var", %{"name" => name, "path" => path_json}, socket) do
  path = Jason.decode!(path_json)
  # Reuse the existing change_operator/value update mechanism to commit the value
  updated_formula = put_in_formula(socket.assigns.value, path, name)
  notify_parent(socket, updated_formula)
  {:noreply, assign(socket, var_input: name, var_suggestions: [], var_active_path: nil)}
end
```

`notify_parent/2` is the existing mechanism the component already uses to push formula changes up.

### 4. Replace the `<select>` in `arg_editor/1`

**File:** `lib/game_web/live/formula_editor_component.ex` — `arg_editor/1` (lines ~189–212)

Replace the entire `<select>` block (and the fallback plain `<input>`) with a single unified
autocomplete widget, regardless of whether `@variables` is empty:

```heex
<div class="relative" phx-click-away="select_var"
     phx-value-name={@var_input} phx-value-path={Jason.encode!(@path)}
     phx-target={@myself}>

  <%!-- Hidden input carries the committed value for form submission --%>
  <input type="hidden"
         name={build_field_name(@field, @path, "value")}
         value={@var_input} />

  <%!-- Visible text input --%>
  <input type="text"
         value={@var_input}
         placeholder="variable path…"
         autocomplete="off"
         class="border border-base-300 rounded px-3 py-2 text-sm bg-base-100 text-base-content w-full"
         phx-change="filter_var"
         phx-debounce="100"
         phx-value-path={Jason.encode!(@path)}
         phx-target={@myself} />

  <%!-- Suggestion dropdown --%>
  <ul :if={@var_suggestions != [] && @var_active_path == @path}
      class="absolute z-50 mt-1 w-full max-h-60 overflow-y-auto
             border border-base-300 rounded bg-base-100 shadow-lg text-sm">
    <%= for var <- @var_suggestions do %>
      <li class="px-3 py-2 cursor-pointer hover:bg-base-200"
          phx-click="select_var"
          phx-value-name={var.name}
          phx-value-path={Jason.encode!(@path)}
          phx-target={@myself}>
        <span class="font-mono">{var.name}</span>
        <span :if={var.description} class="ml-2 text-base-content/50">{var.description}</span>
      </li>
    <% end %>
  </ul>
</div>
```

The hidden input decouples the visible typing state from the submitted value, so partial input
mid-typing doesn't corrupt the formula on save.

### 5. Show all suggestions on focus (optional but recommended)

Add a `phx-focus="filter_var"` with an empty value to the text input so the full variable list
appears as soon as the user focuses the field, matching standard autocomplete UX.

```heex
phx-focus="filter_var"
phx-value-value=""
phx-value-path={Jason.encode!(@path)}
phx-target={@myself}
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game_web/live/formula_editor_component.ex` | Add `var_input`, `var_suggestions`, `var_active_path` assigns; add `filter_var` and `select_var` event handlers; replace `<select>` in `arg_editor/1` with autocomplete widget |

No other files need to change — `Formula.available_variables/1` stays as-is (it becomes the
suggestion source rather than the exhaustive list), form submission paths are unchanged, and no JS
hook is needed.

---

## Open Questions

| Question | Options |
|----------|---------|
| Should typing a value not in the list be allowed? | Yes — that's the whole point. The hidden input commits whatever is in the text field on form submit, whether or not it matched a suggestion. |
| Should suggestions show on empty input (focus)? | Recommended yes — shows the user what's available without requiring a keystroke. |
| Keyboard navigation (↑↓ Enter Escape)? | Out of scope for v1; mouse-click selection is sufficient. Can be added later with a JS hook if needed. |

---

## Verification

1. Open the formula editor on an existing card effect; navigate to a `var` node.
2. Confirm the field renders as a text input pre-populated with the current variable name.
3. Type a partial string (e.g. `"cast"`); confirm the dropdown filters to matching variables.
4. Click a suggestion; confirm the input commits that value and the dropdown closes.
5. Type a variable path not in the list (e.g. `"state.queue"`); save the form; confirm the formula
   stores the typed value verbatim.
6. Open two `var` nodes on the same form; confirm typing in one does not open the dropdown on the
   other.
7. Click outside the dropdown; confirm it closes without changing the committed value.
