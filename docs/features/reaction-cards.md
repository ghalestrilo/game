# Feature: Reaction Cards

## Context

A reaction card, when played, adds a **reaction** to the caster's `reactions` list. A reaction:
- Reserves AP immediately (reducing available AP without spending it yet)
- Has a turn-based timer (expires after N turns)
- Has a JsonLogic trigger condition evaluated against the action context whenever the character is involved in an action
- Fires its effects and consumes the reserved AP when the condition matches
- Can only proc once per trigger event, then is removed

---

## Data Model

### Reaction struct (stored in `character.reactions`)

```elixir
%{
  id: unique_id,           # for deduplication / UI
  trigger: %{...},         # JsonLogic formula (see trigger context below)
  effects: [...],          # list of card effect maps, same format as card.effects
  ap_cost: integer,        # AP reserved (and consumed on proc)
  duration: integer        # turns remaining before expiry
}
```

### Trigger context

When an action is checked against a character's reactions, the formula receives:

```json
{
  "event":        "damaged" | "healed" | "targeted" | "ally_targeted",
  "amount":       integer,       // damage/heal amount (0 for non-numeric events)
  "effect_type":  "damage" | "heal" | "stun" | ...,
  "caster":       { ...character map... },
  "target":       { ...character map (the reactor) ... },
  "attacker":     { ...character map who triggered this... }
}
```

---

## Implementation Plan

### 1. Add `reactions` to Character

**File:** `lib/game/character.ex`

```elixir
defstruct ...,
          reactions: []
```

Add helpers:

```elixir
def add_reaction(character, reaction) do
  %{character | reactions: [reaction | character.reactions]}
end

def remove_reaction(character, reaction_id) do
  %{character | reactions: Enum.reject(character.reactions, &(&1.id == reaction_id))}
end
```

### 2. AP reservation

**File:** `lib/game/character.ex`

AP available to spend must account for reserved AP. Add a helper:

```elixir
def reserved_ap(%__MODULE__{reactions: reactions}) do
  Enum.sum(Enum.map(reactions, & &1.ap_cost))
end
```

Update `has_enough_ap?/2` to subtract reserved AP:

```elixir
def has_enough_ap?(%__MODULE__{ap: ap} = character, cost) when is_integer(ap) do
  ap - reserved_ap(character) >= cost
end
```

`spend_ap/2` is unchanged — reserved AP is only actually spent when the reaction procs.

### 3. The `Reaction` card effect

**New file:** `lib/game/combat/card_effects/reaction.ex`

`process/3` adds the reaction to the caster (not the target — reactions always attach to the caster):

```elixir
defmodule Game.Combat.CardEffects.Reaction do
  defstruct type: :reaction,
            value: nil,
            trigger: %{},     # JsonLogic map
            effects: [],      # list of effect maps
            ap_cost: 0,
            duration: 1,
            value_label: nil

  defimpl Game.Combat.CardEffect do
    def process(%{trigger: trigger, effects: effects, ap_cost: ap_cost, duration: duration},
                _target, combat_state) do
      caster = combat_state.current_turn.player

      reaction = %{
        id: System.unique_integer([:positive]),
        trigger: trigger,
        effects: effects,
        ap_cost: ap_cost,
        duration: duration
      }

      updated_caster = Game.Character.add_reaction(caster, reaction)
      CombatState.update_target(combat_state, caster, updated_caster)
    end

    def animate(_), do: %{label: "REACTION", color: :blue}
    def get_description(%{duration: d}), do: "Set a reaction for #{d} turns"
    def get_icon(_), do: "hero-bolt-solid"
    def get_value_label(%{value_label: l}) when is_binary(l), do: l
    def get_value_label(_), do: ""
    def params(_), do: ["ap_cost", "duration", "trigger", "effects"]
  end
end
```

Register in `lib/game/card.ex`:

```elixir
"reaction" => CardEffects.Reaction
```

### 4. Tick reactions each turn

**File:** `lib/game/combat_state.ex` — `setup_player_turn/1`

After `tick_status_effects`, add a `tick_reactions` step:

```elixir
def setup_player_turn(combat) do
  ticked =
    combat
    |> put_in([:state], :running)
    |> put_in([:current_turn], new_turn(next_player))
    |> tick_status_effects()
    |> tick_reactions()   # add here

  # ... stun check, draw cards, restore AP unchanged
end

defp tick_reactions(%CombatState{current_turn: %{player: player}} = combat) do
  updated_reactions =
    player.reactions
    |> Enum.map(fn r -> %{r | duration: r.duration - 1} end)
    |> Enum.reject(fn r -> r.duration <= 0 end)

  updated_player = %{player | reactions: updated_reactions}
  put_in(combat, [:current_turn, :player], updated_player)
end
```

### 5. Check reactions after each card effect

**File:** `lib/game/card.ex` — `apply_card_effects/4`

After `CardEffect.process/3` resolves for each effect, check the target's (and caster's) reactions:

```elixir
new_combat = CardEffect.process(resolved, effective_target, combat_state)
new_combat = check_reactions(new_combat, effective_target, resolved, combat_state)
```

**New private function:**

```elixir
defp check_reactions(combat, original_target, effect, pre_effect_combat) do
  # Rebuild the fresh target (post-effect) from combat state
  fresh_target =
    CombatState.get_current_queue(combat)
    |> Enum.find(&(&1.id == original_target.id))
    |> Kernel.||(original_target)

  attacker = CombatState.get_current_player(pre_effect_combat)

  trigger_context = build_trigger_context(effect, fresh_target, attacker)

  Enum.reduce(fresh_target.reactions, combat, fn reaction, acc ->
    if reaction_triggers?(reaction, trigger_context) && can_afford_reaction?(fresh_target, reaction) do
      fire_reaction(acc, fresh_target, reaction, attacker)
    else
      acc
    end
  end)
end

defp reaction_triggers?(reaction, context) do
  Game.Formula.resolve(reaction.trigger, context) == true
rescue
  _ -> false
end

defp can_afford_reaction?(character, reaction) do
  character.ap >= reaction.ap_cost
end

defp fire_reaction(combat, reactor, reaction, attacker) do
  # Spend the reserved AP
  updated_reactor = Game.Character.spend_ap(reactor, reaction.ap_cost)
  # Remove the reaction (one-shot)
  updated_reactor = Game.Character.remove_reaction(updated_reactor, reaction.id)
  combat = CombatState.update_target(combat, reactor, updated_reactor)

  # Apply reaction effects with reactor as both caster and target
  # (reactions cast from the reactor's perspective)
  {combat, _anims} = apply_card_effects(combat, reaction.effects, attacker)
  combat
end

defp build_trigger_context(effect, target, attacker) do
  {:ok, target_json} = Jason.encode(target)
  {:ok, target_map} = Jason.decode(target_json)
  {:ok, attacker_json} = Jason.encode(attacker)
  {:ok, attacker_map} = Jason.decode(attacker_json)

  %{
    "event"       => to_string(effect.type),
    "amount"      => Map.get(effect, :value, 0),
    "effect_type" => to_string(effect.type),
    "target"      => target_map,
    "attacker"    => attacker_map
  }
end
```

Note: `fire_reaction` calls `apply_card_effects` recursively — reactions spawned by reaction effects
will not themselves check further reactions (to avoid infinite loops). If needed, pass a
`depth: 0` guard.

### 6. HUD: show active reactions

**File:** `lib/game_web/live/combat_hud.ex` — `character_queue_card` component

Show a small badge per active reaction on each character in the queue, similar to status effects.
Reactions are visible to their owner (and optionally enemies — designer choice).

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/character.ex` | Add `reactions: []` field; add `add_reaction/2`, `remove_reaction/2`, `reserved_ap/1`; update `has_enough_ap?/2` |
| `lib/game/combat/card_effects/reaction.ex` | New effect: attaches reaction to caster |
| `lib/game/card.ex` | Register `"reaction"` in `@effect_types`; call `check_reactions/4` after each `CardEffect.process` in `apply_card_effects`; add `check_reactions`, `fire_reaction`, `build_trigger_context` helpers |
| `lib/game/combat_state.ex` | Add `tick_reactions/1`; call it in `setup_player_turn/1` |
| `lib/game_web/live/combat_hud.ex` | Show reaction badges on character queue cards |

---

## Example Reaction Card

A "Counter Strike" card with `reaction` effect:
```json
{
  "type": "reaction",
  "ap_cost": 2,
  "duration": 2,
  "trigger": {"==": [{"var": "event"}, "damage"]},
  "effects": [{"type": "damage", "value": 5}]
}
```

When played: reserves 2 AP for 2 turns. If the caster takes any damage during that window,
immediately deals 5 damage back to the attacker and spends the 2 AP.

---

## Verification

1. Create a reaction card with the above spec.
2. Play it — confirm `reactions` has one entry, AP available drops by 2 (reserved), animation shows "REACTION".
3. Have an enemy attack the reactor — confirm counter fires (enemy takes 5 damage), AP is spent, reaction is removed.
4. Advance 2 turns without triggering — confirm the reaction expires and AP reservation is released.
5. Try to play a card costing more AP than `available - reserved` — confirm it is blocked.
