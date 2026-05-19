# add-ai-strategy

Author a new `Strategy` — a named, ordered list of tactics that drives an AI-controlled character's turn-by-turn decisions.

## What you need from the user

If not provided in the invocation args, ask for:
1. **Strategy name** — e.g. `"Berserker"`, `"Support Healer"`, `"Rogue Flanker"`
2. **Archetype description** — what the enemy should try to do: when to attack, move, heal, flee
3. **Class it's for** — which `BaseClass` will use this strategy (determines what cards are in hand)
4. **Edge cases** — what should happen when out of range, no valid card in hand, nearly dead

## Architecture overview

A strategy is a **priority list** (ordered top-to-bottom). Each turn the AI scans it from the top, evaluates each tactic's `trigger`, and executes the first match. After each action it restarts the scan — like FF12's Gambit system.

```
Strategy
  └─ tactics: [Tactic, Tactic, ...]   (ordered, evaluated top-to-bottom each pass)
       ├─ trigger: JsonLogic map       (evaluated against {caster, queue, state} → boolean)
       └─ action:  JsonLogic map       (evaluated against same context → action descriptor map)
```

The `action` formula resolves to a map with a `"type"` key. The AI executor (`lib/game/ai.ex`) dispatches on `"type"`:

| `"type"` | What it does |
|---|---|
| `"move_closer"` | Pathfind one step toward nearest enemy |
| `"move_away"` | Pathfind one step away from nearest enemy |
| `"skip_turn"` | End the AI's turn |
| `"damage"`, `"heal"`, `"shield"`, etc. | Find a card with `card_filter` effect type, find a valid target, play it |

For card actions, `"card_filter"` (string) tells the AI which effect type to search for in hand. If absent, it falls back to the `"type"` value.

## Tactic context variables

Both `trigger` and `action` formulas are evaluated against this context:

```
caster.*           — the AI character (all Character struct fields as JSON)
  .hp, .max_hp, .ap, .max_ap
  .team            — team string ("1", "2", ...)
  .position        — [q, r, s] list (not tuple)
  .status_effects  — list of maps: [{type: "stun", value: 1}, ...]
  .cards.hand      — list of card maps (id, name, cost, effects, ...)

queue              — list of all OTHER characters in combat (same shape as caster)
  each item: .hp, .max_hp, .team, .dead, .position, ...

state.current_turn.player      — same as caster
state.current_turn.starting_position  — [q, r, s]
```

Note: `queue` includes both allies and enemies. Filter by team to distinguish them.

## Writing triggers

A trigger is a JsonLogic formula that returns `true` (fire this tactic) or `false` (skip to next).

**Always fire** (use as fallback at the bottom of the list):
```elixir
%{"trigger" => true}
```

**HP threshold** (fire when below 30% HP):
```elixir
%{"trigger" => %{"<" => [
  %{"var" => "caster.hp"},
  %{"*" => [%{"var" => "caster.max_hp"}, 0.3]}
]}}
```

**Has a status effect** (fire when caster has stealth):
```elixir
%{"trigger" => %{"some" => [
  %{"var" => "caster.status_effects"},
  %{"===" => [%{"var" => "type"}, "stealth"]}
]}}
```

**Enemy is in range** (checks if any enemy is within range 2):
```elixir
# Note: distance is not directly in the queue context — use this heuristic:
# trigger true always and let the card action fail + fall through to move_closer
%{"trigger" => true}
```

**Ally needs healing** (any team ally is below max HP):
```elixir
%{"trigger" => %{"some" => [
  %{"var" => "queue"},
  %{"and" => [
    %{"===" => [%{"var" => "current.team"}, %{"var" => "caster.team"}]},
    %{"<" => [%{"var" => "current.hp"}, %{"var" => "current.max_hp"}]}
  ]}
]}}
```

## Writing actions

An action is a JsonLogic formula that resolves to a descriptor map.

**Static action** (just a literal map — no variables needed):
```elixir
%{"action" => %{"type" => "move_closer"}}
%{"action" => %{"type" => "damage", "card_filter" => "damage"}}
%{"action" => %{"type" => "skip_turn"}}
```

**Dynamic action with computed target** (target the lowest-HP enemy):
```elixir
%{"action" => %{
  "type" => "damage",
  "card_filter" => "damage",
  "target_id" => %{"reduce" => [
    %{"filter" => [
      %{"var" => "queue"},
      %{"!=" => [%{"var" => "current.team"}, %{"var" => "caster.team"}]}
    ]},
    %{"if" => [
      %{"<" => [%{"var" => "current.hp"}, %{"var" => "accumulator.hp"}]},
      %{"var" => "current"},
      %{"var" => "accumulator"}
    ]},
    nil
  ]}
}}
```

**Dynamic action with computed target** (target the most-wounded ally):
```elixir
%{"action" => %{
  "type" => "heal",
  "card_filter" => "heal",
  "target_id" => %{"reduce" => [
    %{"filter" => [
      %{"var" => "queue"},
      %{"===" => [%{"var" => "current.team"}, %{"var" => "caster.team"}]}
    ]},
    %{"if" => [
      %{"<" => [
        %{"/" => [%{"var" => "current.hp"}, %{"var" => "current.max_hp"}]},
        %{"/" => [%{"var" => "accumulator.hp"}, %{"var" => "accumulator.max_hp"}]}
      ]},
      %{"var" => "current"},
      %{"var" => "accumulator"}
    ]},
    nil
  ]}
}}
```

## Creating the strategy in code

```elixir
alias Game.{Repo, Content.Strategy}

{:ok, strategy} = Strategy.changeset(%Strategy{}, %{
  name: "Berserker",
  tactics: [
    # Low HP: charge in and attack with maximum damage
    %{
      trigger: %{"<" => [%{"var" => "caster.hp"}, %{"*" => [%{"var" => "caster.max_hp"}, 0.3]}]},
      action:  %{"type" => "damage", "card_filter" => "damage"}
    },
    # Default: close the gap first
    %{trigger: true, action: %{"type" => "move_closer"}},
    # Then attack
    %{trigger: true, action: %{"type" => "damage", "card_filter" => "damage"}},
    # Fallback: end turn (must be last — prevents infinite loop)
    %{trigger: true, action: %{"type" => "skip_turn"}}
  ]
}) |> Repo.insert()
```

**Always end with `skip_turn` as the final fallback tactic.** If no tactic in the list resolves to a successful action, the AI circuit breaker (`@max_actions = 10`) will fire and log a warning.

## Attaching the strategy to a class

```elixir
base_class = Game.Repo.get_by!(Game.Content.BaseClass, class: "wolf")
|> Ecto.Changeset.change(strategy_id: strategy.id)
|> Game.Repo.update!()
```

Or via the admin UI at `/admin/base-classes`, select the class and set the Strategy dropdown.

## Via admin UI

Navigate to `/admin/strategies`. The tactic list uses an inline CRUD editor:
- **Trigger**: formula editor (same component as card effects)
- **Action**: formula editor — enter the action descriptor as a JsonLogic expression that resolves to a map

For simple static actions, the formula is just a literal value node with no operator.

## Testing a strategy in IEx

```elixir
# Load the class with its strategy preloaded
base_class = Game.Content.get_base_class_by_class!("wolf")
char = Game.Character.from_character_data(base_class)

# Build a minimal combat with this character as AI
specs = [
  %{class: "fighter", team: "1", position: {0, 0, 0}, id: 0},
  %{character: char,  team: "2", position: {3, 0, -3}, id: 1}
]
combat = Game.CombatBuilder.build(specs)

# Run one full AI turn
{:ok, updated} = Game.AI.run_turn(combat, char.tactics)

# Or auto-advance through all consecutive AI turns
{:ok, updated} = Game.AI.advance_through_ai_turns(combat)

# Inspect what happened
player = Game.CombatState.get_current_player(updated)
IO.puts("After AI turn: #{player.name} HP=#{player.hp}")
```

## Authoring tips

**Order matters**: put the most specific/urgent conditions at the top; generic fallbacks at the bottom.

**Failed actions fall through**: if a card action fails (e.g. no `card_filter` card in hand, or no target in range), the executor skips that tactic and tries the next one. Design the list so a sensible fallback always exists.

**One action per pass**: the executor fires one tactic, then restarts from the top. This means two tactics that always trigger will alternate each pass — use this to sequence: "if I have a damage card, play it; if I don't, move closer."

**`move_closer` is greedy**: it moves as far as possible toward the nearest enemy in one pass. The next restart will re-evaluate whether the character is now in range to attack.

**`move_away` targets the nearest enemy**: useful for fragile healers or low-HP escape behavior.

**Avoid `trigger: false`**: it's a dead tactic and just adds confusion. Delete unused tactics.

**AP awareness**: the AI does not automatically check AP before picking a card — the card play will fail if AP is insufficient, and the tactic falls through. If a class has variable-cost cards, accept that some turns will end early via the `skip_turn` fallback.

## Common mistakes

- **No `skip_turn` fallback**: without a guaranteed-to-succeed last tactic, the AI hits the 10-action circuit breaker and emits a warning log each turn.
- **`target_id` reduces to a map, but executor expects integer**: `"target_id"` in the action descriptor must be the character's integer `id` field, not the full character map. The `reduce` formula must return `{"var": "current"}` (the character map), and the executor extracts `.id` from it. Make sure you're reducing to the character map, not directly to the id — the executor does `Map.get(char_map, "id")` internally.
- **`card_filter` missing for card actions**: if `"card_filter"` is absent, the AI falls back to using `"type"` as the filter string. If `"type"` is `"damage"` that works fine; for custom action types it may not match any card effect.
- **Status effect type is a string in context**: status effect atoms (`:stealth`, `:dot`) become JSON strings (`"stealth"`, `"dot"`) in the formula context. Always compare with string literals: `{"===": [{"var": "type"}, "stealth"]}`.
- **`queue` includes dead characters**: filter with `{"!==": [{"var": "current.dead"}, true]}` if you only want living targets.
