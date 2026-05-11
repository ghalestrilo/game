# card-effect

Scaffold a new card effect for this game engine.

## What you need from the user

If not provided in the invocation args, ask for:
1. **Effect name** — e.g. `lifesteal`, `freeze`, `taunt` (becomes the module name and type atom)
2. **What it does** — plain English description of the game mechanic
3. **Parameters** — which fields are formula-evaluable (most effects just have `value`; some need extra fields like `damage`, `duration`, `angle`, `attribute`)

## Implementation checklist

Work through these steps in order:

### 1. Create the effect module

File: `lib/game/combat/card_effects/<name>.ex`

Follow this exact structure — every existing effect uses it:

```elixir
defmodule Game.Combat.CardEffects.<Name> do
  alias Game.CombatState
  # alias Game.{Character, Grid} — add as needed

  @derive Jason.Encoder
  defstruct type: :<name>, value: 0, value_label: nil
  # Add extra fields before value_label if needed:
  # defstruct type: :<name>, value: 0, duration: nil, value_label: nil

  @type t() :: %__MODULE__{
          type: atom(),
          value: integer() | map(),
          value_label: String.t() | nil
        }

  defimpl Game.Combat.CardEffect do
    alias Game.Combat.CardEffects.<Name>

    def process(%<Name>{value: amount}, target, %CombatState{} = combat_state) do
      # Implement the mechanic here.
      # - target is a %Game.Character{} or a position tuple {q,r,s}
      # - Return an updated CombatState
      # - Use CombatState.update_target(combat_state, original_target, updated_target)
      # - Use Character.add_status_effect(target, %{type: :<name>, value: amount})
      # - Use Character.apply_damage(target, amount) for damage
    end

    def get_description(%<Name>{value: v}), do: "Description of what #{v} does"
    def get_icon(%<Name>{}), do: "hero-<heroicon-name>-solid"

    def get_value_label(%<Name>{value_label: label}) when is_binary(label), do: label
    def get_value_label(%<Name>{value: v}), do: "#{v}"

    def animate(%<Name>{value: v}), do: %{label: "LABEL", color: :red}
    # color options: :red, :green, :blue, :yellow
    # return nil if no floating animation is needed

    def params(_), do: ["value"]
    # List every field that can be a JsonLogic formula map.
    # Multi-param example: ["value", "damage"] for dot.ex
    # No-param example: [] for cleanse.ex
  end
end
```

**Key patterns to copy from existing effects:**

- **Simple value effect** (damage, heal, shield): just `value`, call a Character helper
- **Status effect** (dot, slow, stun, regen): call `Character.add_status_effect/2` with a map including `type:`, `value:`, and any extra fields; the status is ticked each turn by `CombatState.tick_status_effects/1` — make sure `combat_state.ex` handles the new type there
- **Movement effect** (move): use `Grid.direction_from_angle/1` and `Grid.direction_toward/3`; move step-by-step checking `Grid.tile_blocked?/2`
- **Multi-param effect** (dot, modify_attribute): add struct fields beyond `value`; list them all in `params/1`
- **No-formula effect** (give, cleanse): `params(_), do: []`

### 2. Register the effect type

In `lib/game/card.ex`, add to the `@effect_types` map:

```elixir
"<name>" => CardEffects.<Name>,
```

### 3. Handle the status effect tick (if applicable)

If the effect adds a status that ticks each turn, open `lib/game/combat_state.ex` and find `tick_status_effects/1`. Add a clause for the new type following the existing pattern for `:dot`, `:slow`, `:regen`, etc.

### 4. Verify it compiles

Run `mix compile` and fix any warnings or errors before reporting done.

### 5. Suggest a test card

Show a minimal card definition the user can paste into a seed or fixture to test the effect in-game:

```elixir
%Game.Card{
  id: 999,
  name: "<Effect Name>",
  cost: 2,
  range: 1,
  effects: [%Game.Combat.CardEffects.<Name>{value: 5}]
}
```

## Important constraints

- Do NOT add `@impl Game.Combat.CardEffect` annotations — most existing effects don't use them and it causes compiler warnings for functions that don't map 1:1 to the protocol callbacks
- The `value` field must accept both plain integers AND `map()` (JsonLogic formula) — the formula is resolved before `process/3` is called, so by the time your code runs `value` is always a plain integer
- `@derive Jason.Encoder` is required on the struct so card state serializes for LiveView
- Heroicons reference: use `hero-<name>-solid` or `hero-<name>-mini` — browse at heroicons.com
