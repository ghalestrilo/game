# formula-alias

Create, edit, or debug a reusable named formula alias — used to DRY up conditions shared across multiple card effects or AI tactics.

## What is a formula alias?

A `FormulaAlias` is a named JsonLogic expression stored in the database. When `Game.Formula.resolve/2` encounters `{"alias": ["name"]}` in a formula tree, it expands it in-place before evaluation.

Example — the `caster_is_hidden` alias:
```json
{"some": [{"var": "caster.status_effects"}, {"===": [{"var": "type"}, "stealth"]}]}
```

Used in a card effect value:
```json
{"if": [{"alias": ["caster_is_hidden"]}, 7, 3]}
```

At runtime, `caster_is_hidden` is substituted and the whole expression is evaluated in one pass.

## Creating a new alias

### Via Ecto (seeds / IEx)

```elixir
{:ok, alias} = Game.FormulaAliases.create_formula_alias(%{
  name: "caster_at_low_hp",
  description: "True when caster HP is below 30% of max",
  expression: %{
    "<" => [
      %{"var" => "caster.hp"},
      %{"*" => [%{"var" => "caster.max_hp"}, 0.3]}
    ]
  }
})
```

### Via admin UI

Navigate to `/admin/formula-aliases` in the running app. The formula editor lets you build the expression visually.

### Naming conventions

- Use `snake_case`
- Name it after the *condition*, not the effect: `caster_is_hidden`, `target_is_ally`, `at_melee_range`
- Avoid names that encode the specific value: `caster_has_stealth` not `caster_stealth_eq_2`

## Available context variables in aliases

Aliases are evaluated in the same context as the formula that references them. If the alias is used in a **card effect**, it has access to (see `/formula-debug` for full reference):

- `caster.*` — the casting character (hp, max_hp, ap, team, status_effects, position, cards, ...)
- `target.*` — the targeted character or tile
- `state.*` — the full encoded combat state
- `distance_from_caster`, `cast_distance`
- Directional: `push_delta`, `pull_delta`, `angle_toward_target`, etc.
- AoE-only: `angle_push_from_blast`, `angle_pull_from_blast`, etc.

If used in an **AI tactic trigger**, only `caster`, `queue`, and `state` are available — directional variables are absent.

## Checking status effects in aliases

Status effects are a list of maps on `caster.status_effects` / `target.status_effects`. Each map has at least `"type"` (string) and `"value"` (number). Use `some` to check for a specific type:

```elixir
# caster has stealth
%{"some" => [
  %{"var" => "caster.status_effects"},
  %{"===" => [%{"var" => "type"}, "stealth"]}
]}

# target has dot (poison)
%{"some" => [
  %{"var" => "target.status_effects"},
  %{"===" => [%{"var" => "type"}, "dot"]}
]}

# caster has any debuff (dot, stun, slow, stuck, hex)
%{"some" => [
  %{"var" => "caster.status_effects"},
  %{"in" => [%{"var" => "type"}, ["dot", "stun", "slow", "stuck", "hex"]]}
]}
```

Note: `{"var": "type"}` inside `some`/`filter`/`map` refers to the current element in the list — it does NOT need `status_effects.type` notation.

## Nesting aliases inside aliases

Aliases can reference other aliases. `Game.Formula.resolve/2` collects all alias names in a single pass and expands them all before evaluation:

```elixir
# "target_is_vulnerable" can itself reference "target_has_hex"
%{"or" => [
  %{"alias" => ["target_has_hex"]},
  %{"<" => [%{"var" => "target.hp"}, 5]}
]}
```

## Testing an alias in IEx

```elixir
# Build a minimal context matching a real combat scenario
context = %{
  "caster" => %{
    "hp" => 8,
    "max_hp" => 20,
    "status_effects" => [%{"type" => "stealth", "value" => 2}]
  },
  "target" => %{"hp" => 15, "max_hp" => 20, "team" => "2"},
  "distance_from_caster" => 1
}

# Test the alias inline (simulates what Game.Formula.resolve does internally)
alias_expr = %{"some" => [
  %{"var" => "caster.status_effects"},
  %{"===" => [%{"var" => "type"}, "stealth"]}
]}
JsonLogic.resolve(alias_expr, context)   # → true

# Test via Game.Formula.resolve (requires DB alias to exist)
formula = %{"if" => [%{"alias" => ["caster_is_hidden"]}, 7, 3]}
Game.Formula.resolve(formula, context)   # → 7
```

## Common mistakes

- **Type is a string after JSON round-trip**: status effect `:stealth` atoms become `"stealth"` strings when the character is encoded into formula context. Always compare with a string: `{"===": [{"var": "type"}, "stealth"]}` not `":stealth"`.
- **`{"var": "type"}` only works inside array operators**: `some`, `filter`, `map`, `all`, `none`, `reduce`. Outside of those, it refers to a top-level `"type"` key in the root context (which doesn't exist).
- **Alias not found → empty map**: if `Game.Formula.expand_aliases` can't find the alias name in the DB, it substitutes `%{}` (empty map), which evaluates as falsy. Check the DB record exists and the name matches exactly.
- **Directional variables nil in non-AoE**: `angle_push_from_blast` is nil for non-AoE effects. Don't use blast-relative aliases in conditions meant for single-target cards without a nil guard.
- **Alias evaluated against stale caster state**: aliases in card effect formulas are evaluated after `dispel_stealth` has already run on the caster. The formula context is built from the **pre-dispel** snapshot of combat state (see `Card.process_card/3`), so `caster_is_hidden` correctly sees the caster's stealth status at the moment of casting.
