# AI Strategy Redesign: Formula-Driven Actions

## Overview

Redesign the `Tactic` schema so that `action` is a **JsonLogic formula** (`:map`) that evaluates to a complete **action descriptor map** at runtime, instead of a plain string. This collapses `card_filter` and any future per-tactic selectors into the formula itself, keeping the schema minimal: just `trigger` and `action`, both formulas.

---

## New Tactic Schema

**`lib/game/content/strategy.ex`**

```elixir
defmodule Game.Content.Strategy do
  use Ecto.Schema
  import Ecto.Changeset

  defmodule Tactic do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :trigger, :map, default: %{}  # JsonLogic → boolean
      field :action,  :map, default: %{}  # JsonLogic → action descriptor map
    end

    def changeset(tactic, attrs) do
      tactic
      |> cast(attrs, [:trigger, :action])
      |> validate_required([:action])
    end
  end

  schema "strategies" do
    field :name, :string
    embeds_many :tactics, Tactic, on_replace: :delete
    has_many :base_classes, Game.Content.BaseClass

    timestamps(type: :utc_datetime)
  end

  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:name])
    |> cast_embed(:tactics,
      with: &Tactic.changeset/2,
      sort_param: :tactics_order,
      drop_param: :tactics_delete
    )
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
```

---

## Action Descriptor Shape

The `action` formula resolves to a plain map. The executor reads the `"type"` key to dispatch.

| `"type"` value | Additional keys |
|---|---|
| `"damage"`, `"heal"`, `"shield"`, etc. | `"card_filter"` (string, required); optional `"target_id"` (integer) |
| `"move_closer"`, `"move_away"` | none |
| `"skip_turn"` | none |

### Simple (literal map, no variables)

```json
{ "type": "skip_turn" }
{ "type": "move_closer" }
{ "type": "damage", "card_filter": "damage" }
```

### Dynamic (formula computes fields from context)

Target the lowest-HP enemy:

```json
{
  "type": "damage",
  "card_filter": "damage",
  "target_id": {
    "reduce": [
      {
        "filter": [
          { "var": "queue" },
          { "!==": [{ "var": "current.team" }, { "var": "caster.team" }] }
        ]
      },
      {
        "if": [
          { "<": [{ "var": "current.hp" }, { "var": "accumulator.hp" }] },
          { "var": "current" },
          { "var": "accumulator" }
        ]
      },
      null
    ]
  }
}
```

Heal the most-wounded ally:

```json
{
  "type": "heal",
  "card_filter": "heal",
  "target_id": {
    "reduce": [
      {
        "filter": [
          { "var": "queue" },
          { "===": [{ "var": "current.team" }, { "var": "caster.team" }] }
        ]
      },
      {
        "if": [
          {
            "<": [
              { "/": [{ "var": "current.hp" }, { "var": "current.max_hp" }] },
              { "/": [{ "var": "accumulator.hp" }, { "var": "accumulator.max_hp" }] }
            ]
          },
          { "var": "current" },
          { "var": "accumulator" }
        ]
      },
      null
    ]
  }
}
```

---

## Changes to `lib/game/ai.ex`

### `do_run/3` — resolve the action formula before dispatching

```elixir
defp do_run(combat, tactics, remaining) do
  caster = CombatState.get_current_player(combat)
  context = build_context(caster, combat)

  case find_matching_gambit(tactics, context) do
    nil ->
      {:ok, combat}

    %{"action" => action_formula} = gambit ->
      action = Formula.resolve(action_formula, context)

      case execute(action, caster, combat) do
        {:ok, updated_combat} ->
          do_run(updated_combat, tactics, remaining - 1)

        {:error, reason} ->
          Logger.debug("AI action failed (#{reason}), skipping gambit")
          do_run(combat, tactics -- [gambit], remaining - 1)
      end
  end
end
```

### `execute/3` — dispatch on `"type"` key of resolved action map

```elixir
defp execute(%{"type" => "move_closer"}, caster, combat) do
  # ... same as current move_closer clause
end

defp execute(%{"type" => "move_away"}, caster, combat) do
  # ... same as current move_away clause
end

defp execute(%{"type" => "skip_turn"}, caster, combat) do
  {:ok, elem(Combat.process_action(combat, {:skip_turn, caster}), 1)}
end

defp execute(%{"type" => _action, "card_filter" => filter} = desc, caster, combat) do
  target_id = Map.get(desc, "target_id")

  with {:ok, card}             <- pick_card(caster, filter),
       {:ok, target_pos}       <- find_target(card, caster, combat, target_id),
       {:ok, combat_after_pick} <- Combat.process_action(combat, {:pick_card, caster, card}),
       {:ok, result, _anims}   <- Combat.process_action(combat_after_pick, {:play_card, target_pos}) do
    {:ok, result}
  end
end
```

### `find_target/4` — accept optional `target_id`

```elixir
defp find_target(_card, _caster, combat, target_id) when is_integer(target_id) do
  target = Enum.find(CombatState.get_current_queue(combat), &(&1.id == target_id && !&1.dead))
  if target, do: {:ok, target.position}, else: {:error, "target_id #{target_id} not found or dead"}
end

defp find_target(card, caster, combat, _no_target_id) do
  # existing logic: first in-range enemy
  enemies = enemies_of(caster, combat)
  target_pos =
    Enum.find_value(enemies, fn enemy ->
      case Card.is_target_valid_for_character?(card, enemy, combat) do
        {:ok, _} -> enemy.position
        _ -> nil
      end
    end)
  if target_pos, do: {:ok, target_pos}, else: {:error, "no valid target in range"}
end
```

---

## Changes to `lib/game/character.ex`

In `from_character_data/1`, drop `card_filter` from the tactic map:

```elixir
tactics =
  case base_class.strategy do
    %Game.Content.Strategy{tactics: tactics} ->
      Enum.map(tactics, fn t ->
        %{"trigger" => t.trigger, "action" => t.action}
      end)

    _ ->
      []
  end
```

---

## Changes to `lib/game_web/live/admin/strategy_live.ex`

- Replace the `action` `Backpex.Fields.Select` with `GameWeb.Admin.Fields.FormulaField`
- Remove `card_filter` from `child_fields`
- Extend `parse_tactic_triggers/1` to also parse `"action"` through `Formula.parse_params/1`

```elixir
def fields do
  [
    name: %{module: Backpex.Fields.Text, label: "Name", searchable: true},
    tactics: %{
      module: Backpex.Fields.InlineCRUD,
      label: "Tactics",
      orderable: false,
      type: :embed,
      child_fields: [
        trigger: %{
          module: GameWeb.Admin.Fields.FormulaField,
          label: "Trigger"
        },
        action: %{
          module: GameWeb.Admin.Fields.FormulaField,
          label: "Action"
        }
      ]
    }
  ]
end

defp parse_tactic_triggers(%{"tactics" => tactics} = attrs) when is_map(tactics) do
  parsed =
    Map.new(tactics, fn {k, tactic} ->
      {k, tactic |> parse_formula_field("trigger") |> parse_formula_field("action")}
    end)

  %{attrs | "tactics" => parsed}
end

defp parse_tactic_triggers(attrs), do: attrs

defp parse_formula_field(%{} = tactic, key) do
  case Map.get(tactic, key) do
    val when is_map(val) -> Map.put(tactic, key, Game.Formula.parse_params(val))
    _ -> tactic
  end
end
```

---

## Changes to `lib/mix/tasks/game.push_content_sync.ex`

```elixir
tactics_attrs =
  Enum.map(local_strategy.tactics, fn e ->
    Map.take(e, [:trigger, :action])
  end)
```

---

## Migration

No SQL column change needed — `tactics` is `{:array, :map}` (JSONB). New and old keys coexist in the JSON objects.

A **data migration** is required to convert existing string `action` + `card_filter` to the new map shape:

```elixir
defmodule Game.Repo.Migrations.ConvertTacticActionToFormula do
  use Ecto.Migration
  import Ecto.Query

  def up do
    strategies = Game.Repo.all(Game.Content.Strategy)

    for strategy <- strategies do
      updated_tactics =
        Enum.map(strategy.tactics, fn tactic ->
          action_map =
            case {tactic.action, tactic.card_filter} do
              {nil, _}    -> %{}
              {"move_closer", _} -> %{"type" => "move_closer"}
              {"move_away", _}   -> %{"type" => "move_away"}
              {"skip_turn", _}   -> %{"type" => "skip_turn"}
              {action, nil}      -> %{"type" => action, "card_filter" => action}
              {action, filter}   -> %{"type" => action, "card_filter" => filter}
            end

          %{trigger: tactic.trigger, action: action_map}
        end)

      strategy
      |> Game.Content.Strategy.changeset(%{tactics: updated_tactics})
      |> Game.Repo.update!()
    end
  end

  def down do
    raise "irreversible migration"
  end
end
```

---

## Test Fixture Updates

Existing test tactics using the old string format must be updated:

```elixir
# Before
%{"trigger" => true, "action" => "damage", "card_filter" => "damage"}

# After
%{"trigger" => true, "action" => %{"type" => "damage", "card_filter" => "damage"}}
```

---

## Archetype Examples

### Berserker
```elixir
[
  # Below 30% HP: attack
  %{
    trigger: %{"<" => [%{"var" => "caster.hp"}, %{"*" => [%{"var" => "caster.max_hp"}, 0.3]}]},
    action: %{"type" => "damage", "card_filter" => "damage"}
  },
  # Default: move closer, then attack next pass
  %{trigger: true, action: %{"type" => "move_closer"}},
  %{trigger: true, action: %{"type" => "damage", "card_filter" => "damage"}},
  %{trigger: true, action: %{"type" => "skip_turn"}}
]
```

### Healer (targets most-wounded ally)
```elixir
[
  %{
    trigger: %{
      "some" => [%{"var" => "queue"},
        %{"and" => [
          %{"===" => [%{"var" => "current.team"}, %{"var" => "caster.team"}]},
          %{"<" => [%{"var" => "current.hp"}, %{"var" => "current.max_hp"}]}
        ]}]
    },
    action: %{
      "type" => "heal",
      "card_filter" => "heal",
      "target_id" => %{
        "reduce" => [
          %{"filter" => [%{"var" => "queue"},
              %{"===" => [%{"var" => "current.team"}, %{"var" => "caster.team"}]}]},
          %{"if" => [
            %{"<" => [
              %{"/" => [%{"var" => "current.hp"}, %{"var" => "current.max_hp"}]},
              %{"/" => [%{"var" => "accumulator.hp"}, %{"var" => "accumulator.max_hp"}]}
            ]},
            %{"var" => "current"},
            %{"var" => "accumulator"}
          ]},
          nil
        ]
      }
    }
  },
  %{trigger: true, action: %{"type" => "skip_turn"}}
]
```
