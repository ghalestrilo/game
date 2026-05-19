# add-combat-intent

Add a new combat intent type so that keyboard input, UI events, and AI tactics can all trigger the same action through `GameWeb.CombatController`.

## What you need from the user

If not provided in the invocation args, ask for:
1. **Intent name** — e.g. `recall`, `swap`, `fortify` (becomes the `type:` atom in the intent map)
2. **What it does** — plain English description (this informs the `Combat.process_action` tuple it maps to)
3. **Parameters** — what data the intent carries beyond `type`; e.g. `position`, `card`, `character`, `target_id`
4. **Sources** — which of the three entry points need to produce this intent: keyboard key, UI event name, or AI action string

## Architecture overview

Every action in the game flows through a single normalized **intent map**:

```
Keyboard keydown  ──┐
UI phx-event      ──┤─→ %{type: :action, ...params} ──→ CombatController.dispatch/2 ──→ Game.process_action/2
AI tactic action  ──┘                                    └── validates turn, logs action
```

Three files are involved:

| Concern | File |
|---|---|
| Intent → `Combat.process_action` tuple | `lib/game_web/live/combat_controller.ex` |
| Keyboard key → intent | `lib/game_web/live/combat_controller.ex` |
| LiveView event → intent | `lib/game_web/live/combat_controller.ex` |
| AI gambit → intent | `lib/game/ai.ex` |

`Combat.process_action/2` itself lives in `lib/game/combat.ex` and takes `{:action_name, ...args}` tuples — that layer is **not** changed by adding a new intent unless a new action type is also being added to the game engine.

## Step 1 — Define the intent shape

Pick a `type` atom and decide what parameters it carries. Follow existing patterns:

```elixir
%{type: :move,       position: {q, r, s}}         # positional
%{type: :pick_card,  card: %Game.Card{...}}        # carries a struct
%{type: :play_card,  position: {q, r, s}}          # two variants for same intent
%{type: :play_card,  character: %Game.Character{}} #   (matched separately in to_action/2)
%{type: :skip_turn}                                # no params
```

## Step 2 — Add the dispatch clause

In `lib/game_web/live/combat_controller.ex`, add a clause to `to_action/2`:

```elixir
defp to_action(%{type: :my_intent, position: pos}, player),
  do: {:ok, {:my_action, player, pos}}
```

This is the only required change for new intents. It maps an intent map to the tuple that `Combat.process_action/2` expects.

If the action does not need the current player, pattern match it away:

```elixir
defp to_action(%{type: :my_intent, position: pos}, _player),
  do: {:ok, {:my_action, pos}}
```

If the new intent has multiple parameter variants (like `:play_card`), add one clause per variant:

```elixir
defp to_action(%{type: :my_intent, character: char}, _player),
  do: {:ok, {:my_action_on_character, char}}

defp to_action(%{type: :my_intent, position: pos}, _player),
  do: {:ok, {:my_action, pos}}
```

Optionally add an action log clause (if the default `log_action/3` fallback is too generic):

```elixir
defp log_action(socket, %{type: :my_intent, position: pos}, player),
  do: update_log(socket, "#{player.name} did the thing at #{inspect(pos)}")
```

## Step 3 — Wire the keyboard (if applicable)

In `key_to_intent/2`, add a clause that matches the key string and returns the intent:

```elixir
def key_to_intent("f", _combat), do: %{type: :my_intent}

# Or only active in a specific state:
def key_to_intent("f", %{state: :running} = combat) do
  pos = some_computed_position(combat)
  %{type: :my_intent, position: pos}
end
```

Keys are raw browser key strings. Common values: `"Enter"`, `" "` (space), `"Escape"`, `"Tab"`, letter keys as-is.

`key_to_intent/2` returns `nil` to mean "unhandled" — the caller in `GameLive.handle_event/3` does nothing.

## Step 4 — Wire a UI event (if applicable)

In `event_to_intent/3`, add a clause matching the event name:

```elixir
def event_to_intent("my_event", %{"some_param" => val}, combat) do
  %{type: :my_intent, position: parse_something(val)}
end
```

The third argument is the current `CombatState` — use it to validate state (`:running`, `:card_selected`) or look up characters from `combat.queue`.

Return `nil` to ignore the event silently.

Then in `game_live.ex`, if the event isn't already handled by the generic `"interact"` handler, add:

```elixir
def handle_event("my_event", params, socket) do
  combat = socket.assigns.game_state.combat
  case CombatController.event_to_intent("my_event", params, combat) do
    nil    -> {:noreply, socket}
    intent -> CombatController.dispatch(socket, intent)
  end
end
```

## Step 5 — Wire the AI (if applicable)

In `lib/game/ai.ex`, add an `execute/3` clause that handles the new AI action string:

```elixir
defp execute(%{"action" => "my_action"}, caster, combat) do
  pos = compute_target(caster, combat)
  apply_intent(combat, %{type: :my_intent, position: pos})
end
```

`apply_intent/2` (defined at the bottom of `ai.ex`) mirrors `CombatController.to_action/2` — it translates an intent map to a `Combat.process_action/2` call directly (without going through the LiveView layer). Add a clause there too if needed:

```elixir
defp apply_intent(combat, %{type: :my_intent, position: pos}) do
  caster = CombatState.get_current_player(combat)
  Combat.process_action(combat, {:my_action, caster, pos})
end
```

Then the AI tactic formula can produce `%{"type" => "my_action"}` in its resolved `action` map and it will route correctly.

## Step 6 — Verify

```bash
mix compile
```

No new errors or warnings should appear.

Test manually:
- Trigger the keyboard key or UI event in the sandbox (`/sandbox`) and confirm the action fires
- If AI-driven: create or update a strategy with `action: %{"type" => "my_action"}` and run a campaign battle to see the AI use it

## Common mistakes

- **Missing `apply_intent/2` clause in `ai.ex`**: `CombatController.dispatch/2` is a LiveView function and cannot be called from `ai.ex`. The AI must use `apply_intent/2` which speaks directly to `Combat.process_action/2`.
- **`to_action/2` catchall fires instead**: the last clause `to_action(_, _), do: {:error, "Unknown intent"}` will catch any unmatched pattern. If your new intent silently does nothing, check the pattern — a misspelled atom like `:my_intnet` won't match.
- **Returning wrong tuple from `to_action/2`**: the return must be `{:ok, action_tuple}` or `{:error, reason}`. Returning a bare action tuple will crash `dispatch/2`.
- **Forgetting the `_player` arg**: `to_action/2` always receives `(intent, player)` as two arguments. If your action doesn't need the player, use `_player`.
