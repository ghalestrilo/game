# combat-sim

Simulate turns of a combat scenario and report what happened — useful for balancing cards, verifying effect logic, and checking AI behaviour.

## What you need from the user

Clarify anything not provided:
- **Scenario** — which characters, classes, positions, and decks; or just "use the default sandbox setup"
- **How many turns** to simulate (default: until game over or 10 turns)
- **What to report** — damage dealt, effects applied, card choices, positioning, or just final HP

## Step 1 — Build or locate the combat state

**Option A — Use a running sandbox** (fastest): If the dev server is running, the user can open `/sandbox` in the browser with custom initial state via the URL parameter. Remind them of the format:
```
/sandbox?initial_state=[0_0_0:fighter:1,-3_0_3:mage:2]
```

**Option B — Simulate in IEx** (scriptable): Build a `CombatState` directly:

```elixir
# In `iex -S mix`

# Option 1: Use the seed classes (fighter, mage) if DB is seeded
specs = [
  %{class: "fighter", team: "1", position: {0, 0, 0}, id: 1},
  %{class: "mage",    team: "2", position: {3, 0, -3}, id: 2}
]
combat = Game.CombatBuilder.build(specs)

# Option 2: Build a character with a custom hand for precise testing
card = %Game.Card{id: 0, name: "Strike", cost: 1, range: 1,
                  effects: [%Game.Combat.CardEffects.Damage{value: 5}]}
char = %Game.Character{
  id: 1, name: "TestFighter", team: "1",
  hp: 20, max_hp: 20, ap: 3, max_ap: 3,
  movement_range: 2, hand_size: 5,
  position: {0, 0, 0},
  cards: %{draw: List.duplicate(card, 10), hand: [], discard: []},
  status_effects: [], tactics: []
}
specs = [
  %{character: char, team: "1", position: {0, 0, 0}, id: 1},
  %{class: "fighter", team: "2", position: {3, 0, -3}, id: 2}
]
combat = Game.CombatBuilder.build(specs)
```

Note: `CombatBuilder.build/1` calls `Character.draw_cards(char, 5)` on each character, so hands are dealt automatically.

## Step 2 — Simulate turns

Use `Game.Combat.process_action/2` to advance the state. Show the user the IEx pattern, or run it yourself via `Bash` if given permission:

```elixir
# Simulate one full round (both players take a turn):
defmodule Sim do
  def run(combat, turns_left) when turns_left <= 0 or combat.state == :game_over, do: combat

  def run(combat, turns_left) do
    player = combat.current_turn.player
    IO.puts("--- #{player.name}'s turn (HP: #{player.hp}/#{player.max_hp}, AP: #{player.ap}) ---")

    # Try to play first card in hand that's affordable and in range
    case pick_action(combat, player) do
      {:play, card, target} ->
        IO.puts("  Plays #{card.name} on #{target.name}")
        {:ok, after_pick, _} = Game.Combat.process_action(combat, {:pick_card, player, card})
        {:ok, after_play, _} = Game.Combat.process_action(after_pick, {:play_card_on_character, target})
        run(after_play, turns_left - 1)

      :skip ->
        IO.puts("  Skips turn")
        {:ok, after_skip, _} = Game.Combat.process_action(combat, {:skip_turn, player})
        run(after_skip, turns_left - 1)
    end
  end

  defp pick_action(combat, player) do
    queue = Game.CombatState.get_current_queue(combat)
    enemies = Enum.filter(queue, &(to_string(&1.team) != to_string(player.team) and not &1.dead))
    hand = player.cards.hand

    card = Enum.find(hand, &(&1.cost <= player.ap))

    case {card, enemies} do
      {nil, _} -> :skip
      {_, []} -> :skip
      {card, [target | _]} -> {:play, card, target}
    end
  end
end

final = Sim.run(combat, 10)
IO.puts("\n=== Final state ===")
Game.CombatState.get_current_queue(final)
|> Enum.each(fn c ->
  IO.puts("#{c.name} (team #{c.team}): #{c.hp}/#{c.max_hp} HP, dead=#{c.dead}")
end)
IO.puts("Combat state: #{final.state}")
```

Adjust `pick_action` to match what the user wants to test — e.g. always move first, target lowest HP, test a specific card.

## Step 3 — Report findings

Summarize the simulation results clearly:

```
Turn 1: Fighter (20 HP) plays Strike on Mage → Mage takes 5 damage (15 HP remaining)
Turn 2: Mage (15 HP) plays Fireball on Fighter → Fighter takes 8 damage (12 HP remaining)
Turn 3: Fighter plays Strike → Mage takes 5 damage (10 HP remaining)
...
Turn 6: Fighter plays Strike → Mage dies (0 HP)
Game over: Fighter wins

Final HP: Fighter 8/20, Mage 0/20
Total damage dealt — Fighter: 25, Mage: 16
Cards played — Fighter: Strike x5, Mage: Fireball x2
```

## Step 4 — Highlight balance concerns

Flag any of these automatically:

- **One-sided**: one team deals >2× the damage of the other
- **Turn count**: game ends in <3 turns (too swingy) or >15 turns (too slow)
- **AP starvation**: a player regularly skips because no card is affordable
- **Effect stacking**: a status effect value exceeds HP at any point during the sim
- **No decisions**: if the "best" action is always obvious (first affordable card on first enemy), the deck may need more variety

## Common simulation scenarios

**Card balance**: Give one character a hand of only the new card, the other a standard deck. Measure how many turns the new card takes to kill.

**AoE test**: Position 3 enemies in a cluster, fire an AoE card, check all are hit.

**AI verification**: Set `tactics` on a character and call `Game.AI.run_turn(combat, character.tactics)` to see what action it chooses.

**Status effect timing**: Play a DoT effect, then simulate 5 turns calling `Game.CombatState.tick_status_effects(combat)` each turn and report HP after each tick.

## Status effect tick (standalone)

To test how a status effect decays without playing cards:

```elixir
# Apply a DoT manually
dotted = Game.Character.add_status_effect(target, %{type: :dot, damage: 3, value: 3})
combat2 = Game.CombatState.update_target(combat, target, dotted)

# Tick 3 turns
Enum.reduce(1..3, combat2, fn turn, cs ->
  ticked = Game.CombatState.tick_status_effects(cs)
  player = ticked.current_turn.player
  IO.puts("After turn #{turn}: #{player.name} HP = #{player.hp}")
  ticked
end)
```
