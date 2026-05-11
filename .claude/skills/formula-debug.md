# formula-debug

Explain, trace, or fix a JsonLogic formula used in a card effect or AI tactic in this game.

## What you need from the user

The user will provide one of:
- A formula map (JSON/Elixir) they want explained or evaluated
- A card effect or AI tactic that isn't behaving as expected
- A description of what they want a formula to compute

## Step 1 — Identify the formula's context

Formulas are evaluated in two distinct contexts:

**Card effect context** — built by `Game.Card.build_effect_context/3` in `lib/game/card.ex`:

| Variable | Type | Description |
|---|---|---|
| `caster` | map | Current player. Fields: `id`, `name`, `hp`, `max_hp` (effective), `ap`, `max_ap` (effective), `position` (`{q,r,s}` as list), `team`, `dead`, `status_effects`, `cards.draw/hand/discard` |
| `target` | map | Target character or `%{"position" => [q,r,s]}` for tile targets |
| `state` | map | Full encoded `CombatState` including `queue`, `current_turn`, `grid` |
| `pull_delta` | `%{"q"=>n,"r"=>n,"s"=>n}` | Direction from target toward caster (for pull moves) |
| `push_delta` | `%{"q"=>n,"r"=>n,"s"=>n}` | Direction from caster toward target (for push moves) |
| `angle_toward_target` | integer 0–5 | Hex direction index caster→target |
| `angle_toward_caster` | integer 0–5 | Hex direction index target→caster |
| `distance_from_caster` | integer | Hex distance between caster and target |
| `cast_distance` | integer | Distance at time of card selection (frozen) |
| `push_delta_from_blast` | map | (AoE only) Push direction from blast origin |
| `pull_delta_from_blast` | map | (AoE only) Pull direction toward blast origin |
| `angle_push_from_blast` | integer | (AoE only) Angle away from blast origin |
| `angle_pull_from_blast` | integer | (AoE only) Angle toward blast origin |

**AI tactic trigger context** — built by `Game.AI` for `run_turn/2`:

| Variable | Description |
|---|---|
| `caster` | The AI character |
| `queue` | Full turn queue as list of encoded characters |
| `state` | Encoded combat state |

Note: AI triggers do NOT have `pull_delta`, `push_delta`, `angle_*`, or `distance_*` — those are only in effect context.

## Step 2 — Explain the formula

Translate the JsonLogic tree into plain English, operator by operator. Show the evaluation order.

**Operator reference for this codebase:**

| Operator | Usage | Notes |
|---|---|---|
| `{"var": "path.to.value"}` | Read a variable | Dot notation for nested maps |
| `{"==": [a, b]}` | Equality | Use `===` for strict (no coercion) |
| `{"!=": [a, b]}` | Inequality | |
| `{">": [a, b]}`, `{">=": ...}` | Comparison | |
| `{"+": [a, b]}`, `{"-": ...}`, `{"*": ...}`, `{"/": ...}` | Arithmetic | |
| `{"if": [cond, then, else]}` | Conditional | Can chain: `[c1, t1, c2, t2, else]` |
| `{"and": [...]}`, `{"or": [...]}` | Boolean logic | |
| `{"!": x}` | Logical NOT | |
| `{"max": [...]}`, `{"min": [...]}` | Min/max | |
| `{"map": [array, formula]}` | Transform array | `{"var": ""}` refers to current element |
| `{"filter": [array, formula]}` | Filter array | |
| `{"reduce": [array, formula, initial]}` | Fold array | `{"var": "current"}` and `{"var": "accumulator"}` |
| `{"some": [array, formula]}` | Any match | |
| `{"all": [array, formula]}` | All match | |
| `{"none": [array, formula]}` | No match | |
| `{"in": [needle, haystack]}` | Membership | |
| `{"cat": [...]}` | String concat | |
| `{"alias": "name"}` | Named formula | Expands from `Game.FormulaAliases` DB table |
| `{"%": [a, b]}` | Modulo | |

## Step 3 — Trace with concrete values (if the user provides game state)

If the user gives character stats or a combat scenario, substitute actual values and show the result step by step:

```
Formula: {"*": [{"var": "caster.hp"}, 0.5]}
caster.hp = 14
Step 1: var "caster.hp" → 14
Step 2: * [14, 0.5] → 7.0
Result: 7
```

If no concrete values are provided, show the general shape of the output.

## Step 4 — Spot common mistakes

Check for these pitfalls:

- **Wrong context**: using `pull_delta` in an AI tactic (not available there)
- **Type mismatch**: comparing `caster.team` (string in JSON) with an integer literal — use `{"===": [{"var": "caster.team"}, "1"]}` not `1`
- **Missing target**: using `target.hp` in an AoE effect where target might be a tile map without `hp`
- **Hex direction confusion**: `angle_toward_target` pushes target away; `angle_toward_caster` pulls target in; `push_delta` moves target toward the pushed direction from the caster perspective
- **Nil cast_distance**: `cast_distance` is nil for self-targeting cards — guard with `{"if": [{"var": "cast_distance"}, ..., 0]}`
- **Formula not resolving**: a field's value must be a `map()` for it to be formula-resolved; if it's stored as a string like `"5"`, it's treated as a literal and never evaluated

## Step 5 — Suggest or fix the formula

If the user wants to compute something new, write the JsonLogic formula that achieves it. Always show the Elixir map syntax (not JSON) since that's what goes in effect structs and DB records:

```elixir
# "damage equal to caster's missing HP"
%{"+" => [
  %{"-" => [%{"var" => "caster.max_hp"}, %{"var" => "caster.hp"}]},
  1
]}

# "push angle away from blast origin, or toward target if not AoE"
%{"if" => [
  %{"var" => "angle_push_from_blast"},
  %{"var" => "angle_push_from_blast"},
  %{"var" => "angle_toward_target"}
]}
```

## Testing a formula in IEx

Suggest this snippet to evaluate a formula interactively:

```elixir
# Minimal context for testing
context = %{
  "caster" => %{"hp" => 10, "max_hp" => 20, "ap" => 2, "max_ap" => 3, "team" => "1"},
  "target" => %{"hp" => 15, "max_hp" => 20, "team" => "2"},
  "distance_from_caster" => 2,
  "cast_distance" => 2
}

formula = %{"*" => [%{"var" => "caster.hp"}, 2]}
Game.Formula.resolve(formula, context)
```

Note: `Game.Formula.resolve/2` also expands `{"alias": "name"}` nodes by querying the DB, so aliases work in IEx as long as the Repo is running (it is in `iex -S mix`).
