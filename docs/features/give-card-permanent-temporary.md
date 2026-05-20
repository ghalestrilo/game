# Feature: Give Card Effect — Permanent vs Temporary

## Context

The `Give` card effect (`lib/game/combat/card_effects/give.ex`) already adds a card to a target's
hand, draw, or discard pile mid-combat. The feature extends it with a `permanently` boolean:

- `permanently: true` (default, current behavior) — card stays in the deck after combat ends.
- `permanently: false` — card is removed from the character's entire deck when combat ends.

Because cards only live in the in-memory `Character` struct (there is no card-persistence layer),
"temporary" just means the card is tagged and stripped out before the post-combat shop phase begins.

---

## Implementation Plan

### 1. Tag temporary cards on the `Game.Card` struct

**File:** `lib/game/card.ex`

Add a `temporary` boolean field to the `Card` struct (defaults to `false` so all existing cards are
unaffected):

```elixir
defstruct [
  ...existing fields...,
  temporary: false
]
```

No schema or migration needed — `Game.Card` is a runtime struct, not an Ecto schema.

### 2. Extend the `Give` effect struct with `permanently`

**File:** `lib/game/combat/card_effects/give.ex`

Add `permanently: true` to the struct (true = permanent, matching current behaviour as the default):

```elixir
defstruct type: :give, value: nil, card: nil, pile: "hand", permanently: true, value_label: nil
```

In `process/3`, when `permanently: false`, build the card with `temporary: true`:

```elixir
def process(%Give{card: card_id, pile: pile, permanently: permanently}, target, %CombatState{} = combat_state)
    when is_integer(card_id) do
  pile_atom = pile_to_atom(pile)

  base_card = Game.BaseCards.get_base_card!(card_id)
  game_card  = base_card_to_card(base_card)
  game_card  = if permanently, do: game_card, else: %{game_card | temporary: true}

  updated_target = %{target | cards: Map.update!(target.cards, pile_atom, &[game_card | &1])}
  CombatState.update_target(combat_state, target, updated_target)
end
```

Update `params/1` to expose the new field in the admin card builder:

```elixir
def params(_), do: ["card", "pile", "permanently"]
```

Update `get_description/1`:

```elixir
def get_description(%Give{pile: pile, permanently: false}), do: "Give target a temporary card into their #{pile}"
def get_description(%Give{pile: pile}),                     do: "Give target a card into their #{pile}"
```

### 3. Strip temporary cards at end of combat

**File:** `lib/game.ex` — `handle_call(:enter_shop, ...)`

Before transitioning to the shop, strip temporary cards from every character's full deck (draw +
hand + discard):

```elixir
def handle_call(:enter_shop, _from, state) do
  if state.combat.state == :game_over do
    updated_combat = state.combat
      |> strip_temporary_cards()
      |> then(&%{&1 | state: :shop, shop_cards: generate_shop_cards(4)})

    updated_state = %{state | combat: updated_combat}
    {:reply, {:ok, updated_state}, updated_state}
  else
    {:reply, {:error, "Can only enter shop after combat is over"}, state}
  end
end

defp strip_temporary_cards(combat) do
  strip = fn character ->
    updated_cards = Map.new(character.cards, fn {pile, cards} ->
      {pile, Enum.reject(cards, & &1.temporary)}
    end)
    %{character | cards: updated_cards}
  end

  updated_queue = Enum.map(combat.queue, strip)

  updated_current_turn =
    if combat.current_turn.player,
      do: %{combat.current_turn | player: strip.(combat.current_turn.player)},
      else: combat.current_turn

  %{combat | queue: updated_queue, current_turn: updated_current_turn}
end
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/card.ex` | Add `temporary: false` field to `Card` struct |
| `lib/game/combat/card_effects/give.ex` | Add `permanently: true` field; set `temporary: true` on card when `permanently: false`; update `params`, `get_description` |
| `lib/game.ex` | Call `strip_temporary_cards/1` in `handle_call(:enter_shop, ...)` before entering shop |

---

## Verification

1. In the admin, create a card with a `give` effect, set `permanently: false`.
2. Start a combat; have a character play that card targeting an ally.
3. Confirm the ally receives the card in their hand with `temporary: true`.
4. End combat and enter the shop — confirm the temporary card is no longer in any pile of the ally's
   deck.
5. Repeat with `permanently: true` (default) — confirm the card persists into the shop phase.
