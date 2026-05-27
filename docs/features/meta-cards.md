# Feature: Meta-Cards (Card Variants)

## Context

Meta-cards are single-use cards that permanently modify another card in your deck for the rest of
the run. They are inspired by physical TCG printing variants — foil, holographic, first edition,
etc. — where the *physical property* of the card translates into a *gameplay property* that reflects
the feeling of that variant.

The key design principle: variants affect a card's **relationship with time, information, or
acquisition** rather than being raw stat increases. A foil card isn't just stronger — it behaves
differently in a way that matches why collectors value the physical version.

Meta-cards are found in boosters (rare/legendary rarity), never in starting decks.

---

## Data Model

Meta-cards are regular `BaseCard` entries with a special effect type `"apply_variant"`. When
played, the player chooses a target card from their deck; the variant is attached to that card as
a permanent modifier for the rest of the run.

Variants are stored on the runtime `Game.Card` struct as a nullable atom field:

```elixir
# lib/game/card.ex
defstruct ...,
          variant: nil   # :foil | :holographic | :first_edition | :misprint | :signed | :shadowless | :promo
                         # :echo | :volatile | :widened | :discardable | :negative
```

This field is not persisted to `BaseCard` — variants are run-state only, applied at draft time.

The `apply_variant` effect targets a card in the player's own deck rather than a character on the
board. It pops itself from the deck and sets `variant` on the chosen card.

---

## Variants

### Foil
> *The card catches light differently; it stands out in your hand.*

A foil card always rises to the top of the draw pile when shuffled. It is guaranteed to be drawn
first among its copies each cycle.

**Implementation:** In `Character.shuffle_draw_pile/1`, after shuffling, move all foil cards to the
front. The guarantee is positional, not statistical — no RNG involved.

**Feel:** Reliable access. You always have your foil card available when you need it.

---

### Holographic
> *The image shifts depending on angle; it shows you something hidden.*

When played, a holographic card reveals one piece of hidden information in addition to its normal
effect:
- Stealthed characters within range become visible to the caster for 1 turn
- The contents of the opponent's hand are revealed for 1 turn (shown as card count + effect types,
  not full detail)

**Implementation:** Add a post-effect hook in `apply_card_effects/4` that checks `card.variant ==
:holographic` and appends a `reveal` side-effect to the animation/state pipeline.

**Feel:** Sensory. The card sees more than ordinary cards do.

---

### First Edition / Test Print
> *The original printing, before the errata — the pre-nerf numbers.*

A first edition card uses boosted base values: all numeric effect values are increased by 2. Formula-
based values (`Snipe`, `Lifebleed`, `Berserk`) gain a flat `+2` addend appended to the outermost
expression.

**Implementation:** Applied at variant-attachment time, not at play time — the card's `effects`
list is mutated when the meta-card is played. No runtime check needed; the card just has different
numbers.

**Feel:** Historical power. Rewards players who "know the card's history."

---

### Misprint
> *Something went wrong at the factory.*

At the start of each combat, a misprint card receives a random mutation: one of its numeric effect
values is randomised within ±50% of its base. The mutation rerolls each combat; within a single
combat it is stable.

**Implementation:** In `CombatState.init/1` (or wherever player decks are hydrated into the combat
state), iterate cards with `variant: :misprint` and apply a seeded random delta to their effect
values. Store the mutated value on the runtime card only — the base card is unchanged.

**Feel:** High variance, cult appeal. You never quite know what you're holding.

---

### Signed
> *A player or artist left their mark on it; it carries a history.*

A signed card gains a cumulative +1 to all its numeric effect values for every time it has been
played this run. Tracked as a `play_count` integer on the runtime card.

```elixir
defstruct ...,
          variant: nil,
          play_count: 0
```

**Implementation:** In the card-play pipeline (`Game.Card.play/3` or equivalent), after resolving
effects, if `card.variant == :signed`, increment `card.play_count` on the copy returned to the draw
pile. When resolving effect values at play time, add `play_count` to any numeric value.

**Feel:** Rewards commitment. A signed `Heal` you've cast 12 times heals for 17 instead of 5.

---

### Shadowless
> *An early printing detail — no drop shadow under the art.*

A shadowless card costs 0 AP but can only be played as the **first action** of your turn. If you
have already spent AP this turn, the card is unplayable.

**Implementation:** Add a play-eligibility check in the card targeting/play validation path. If
`card.variant == :shadowless` and `current_turn.ap_spent > 0`, the card is greyed out and
unplayable. AP cost is overridden to 0 at display and spend time.

**Feel:** Pure tempo. Rewards opening with it; punishes holding it for later.

---

### Echo
> *A duplicate that shouldn't exist — the press ran twice.*

Playing an echo card creates a copy of itself in your hand immediately after resolving. The copy is
a plain card (no variant) so it won't echo again. Net effect: you play the card twice per cycle at
the cost of one extra hand slot.

**Implementation:** In the card-play pipeline, after resolving effects, if `card.variant == :echo`
push a plain copy of the card (same `base_card_id`, `variant: nil`) onto `player.cards.hand`.

**Feel:** Compounding. Especially strong on cheap cards (`Strike`, `Moonfire`, `Hide`) where
flooding your hand with copies is low-risk. Pairs destructively with `Unholy Vigor` (discard your
hand to heal — now you have twice as many cards to discard).

---

### Volatile
> *The card costs double AP but does not self-destruct.*

A volatile card has its AP cost multiplied by 2, but any `self_destruct` effect is stripped from
it. This makes one-shot nuke cards like `Repent`, `Blood Price`, and `Soulbind` repeatable at a
steep but sustainable price.

**Implementation:** Applied at variant-attachment time: double the `ap` field and remove any effect
with `type: "self_destruct"` from the effects list. No runtime check needed after that.

**Feel:** The trade is obvious and painful — but you get to keep your legendary. Suggests a
dedicated archetype around high-AP self-destruct cards.

---

### Widened
> *The blast radius was miscalculated in production.*

A widened card increases the `range` of all its AoE effects by 1. On cards like `Arcane Explosion`,
`Whirlwind`, `Fireball`, and `Consecration` this meaningfully expands coverage. On single-target
cards it has no effect, so this variant is only worth applying to area cards — which creates a
natural decision point at draft time.

**Implementation:** Applied at variant-attachment time: increment the top-level `card.range` field
and the `range` field on each effect that has one set.

**Feel:** Spatial. Transforms precision tools into crowd-control tools. A widened `Haste` becomes
a mass haste.

---

### Discardable
> *The card activates on the way out, not on the way in.*

A discardable card can be played directly from hand into the discard pile without targeting,
spending 0 AP, triggering all its effects as if it had been played normally. This turns the discard
pile into a second hand and makes deliberate cycling a viable strategy.

Cards with discard synergies (`Unholy Vigor`, `Overload`, `Regret`) become especially potent when
paired with a discardable card — you can dump it on demand without spending AP, then benefit from
the discard count.

**Implementation:** Add a secondary play mode in the card UI: a "Discard" button visible only when
`card.variant == :discardable`. This path calls the same effect resolution pipeline as normal play
but skips targeting (using the caster as default target where needed) and sets `ap_cost` to 0 for
that resolution.

**Feel:** The most original variant. Changes what "playing a card" means and creates a whole new
axis of hand management.

---

### Negative
> *The card was developed in reverse — everything came out wrong.*

A negative card has its AP cost sign-flipped (playing it restores AP rather than spending it) and
every numeric value that resolves to an integer at play time is negated. The card's effects still
execute — damage becomes healing, healing becomes damage, shields drain HP instead of adding to it,
movement pushes in the opposite direction.

Formula-based values (`Snipe`, `Lifebleed`, `Berserk`) are negated after the formula resolves, not
before — the formula still evaluates against live game state, and the resulting integer is then
flipped. A `Snipe` that would deal 14 instead heals the target for 14.

**AP behaviour:** `ap: -ap`. If the card cost 2 AP, playing it gives back 2 AP. If the card
already had negative AP (e.g. `Blood Magic` at -3), it now costs 3. The sign always flips.

**Implementation:** Applied at variant-attachment time for AP inversion (`ap: -card.ap`). Value
negation happens at play time: after each effect resolves its final integer value, multiply by -1
before applying. This requires a thin wrapper in the effect resolution path that checks
`card.variant == :negative` and negates the resolved value. Formula-based values must be fully
evaluated before negation — the formula itself is not modified.

**Feel:** The most dangerous variant to apply carelessly, and the most rewarding to build around
deliberately. A negative `Heal` is a ranged execute. A negative `Iron Skin` depletes a target's
HP by 5. A negative `Blood Magic` costs 3 AP but deals -3 damage (i.e. heals). The card's
*identity* inverts — it does something completely different while wearing the same name.

---

### Promo
> *Given out at events, not in packs — rarer than rare.*

Promo cards cannot appear in boosters. They are only obtainable through specific in-game triggers:
boss drops, hidden map secrets, or end-of-run rewards. Mechanically they are strong cards (rare or
legendary base), but their distinguishing property is **acquisition path**, not stats.

**Implementation:** A boolean flag `promo: true` on `BaseCard` (or a separate rarity tier
`:promo`). The booster pool query filters these out. Drop tables for bosses/secrets explicitly
reference promo card IDs.

**Feel:** Discovery and exclusivity. Finding one is an event, not a draft pick.

---

## Implementation Plan

### 1. Add `variant` and `play_count` to runtime `Game.Card`

**File:** `lib/game/card.ex`

```elixir
defstruct ...,
          variant: nil,
          play_count: 0
```

### 2. The `apply_variant` card effect

**New file:** `lib/game/combat/card_effects/apply_variant.ex`

When played, opens a targeting modal scoped to the player's own draw pile. Player selects a card;
the variant is applied to it:

```elixir
def process(%{variant: variant}, _target, combat_state) do
  # target here is a card_id in the player's draw pile, not a character
  # UI flow: show card-picker modal, then call apply_variant_to_card/3
end

defp apply_variant_to_card(combat_state, card_id, variant) do
  player = combat_state.current_turn.player
  updated_draw = Enum.map(player.cards.draw, fn card ->
    if card.id == card_id, do: %{card | variant: variant}, else: card
  end)
  # For :first_edition, also mutate effect values at this point
  updated_player = put_in(player.cards.draw, updated_draw)
  CombatState.update_player(combat_state, updated_player)
end
```

### 3. Foil: shuffle priority

**File:** `lib/game/character.ex` — `shuffle_draw_pile/1` (or wherever shuffling occurs)

After shuffle, partition and reorder:

```elixir
{foils, rest} = Enum.split_with(draw_pile, &(&1.variant == :foil))
foils ++ rest
```

### 4. Holographic: post-play reveal hook

**File:** `lib/game/card.ex` — `apply_card_effects/4`

After all effects resolve, check for holographic variant and append reveal side-effect to the
returned animation list. Reveal state (`revealed_characters`, `revealed_hand`) is stored on
`CombatState` with a 1-turn TTL, cleared in `setup_player_turn/1`.

### 5. Misprint: per-combat mutation

**File:** `lib/game/combat_builder.ex` (or `CombatState.init/1`)

When hydrating player cards into combat state, for each card with `variant: :misprint`, apply a
seeded random delta (±50%) to all numeric effect values.

### 6. Signed: play count tracking

**File:** `lib/game/card.ex` — card play pipeline

After a signed card resolves its effects, increment `play_count` on the card before returning it to
the discard pile. When building effect values at play time, add `play_count` to any integer value.

### 7. Shadowless: play eligibility

**File:** wherever card play eligibility is validated (likely `Game.Combat` or `CombatState`)

Add guard: `if card.variant == :shadowless and combat_state.current_turn.ap_spent > 0, do:
{:error, :not_eligible}`. Override AP display to 0 for shadowless cards.

### 8. Echo: copy-on-play

**File:** `lib/game/card.ex` — card play pipeline

After effects resolve, if `card.variant == :echo`, push a plain copy onto the player's hand:

```elixir
plain_copy = %{card | id: new_id(), variant: nil}
put_in(combat_state, [:current_turn, :player, :cards, :hand], [plain_copy | player.cards.hand])
```

### 9. Volatile: attachment-time mutation

**File:** `lib/game/combat/card_effects/apply_variant.ex` — `apply_variant_to_card/3`

When applying `:volatile`, transform the target card:

```elixir
updated_card = %{card |
  ap: card.ap * 2,
  effects: Enum.reject(card.effects, &(&1.type == "self_destruct"))
}
```

### 10. Widened: attachment-time range expansion

**File:** `lib/game/combat/card_effects/apply_variant.ex` — `apply_variant_to_card/3`

When applying `:widened`, increment range fields:

```elixir
updated_effects = Enum.map(card.effects, fn e ->
  if is_integer(e.range), do: %{e | range: e.range + 1}, else: e
end)
updated_card = %{card | range: (card.range || 0) + 1, effects: updated_effects}
```

### 11. Discardable: secondary play mode

**File:** wherever card play is handled in the LiveView (`combat_hud.ex` or `game_live.ex`)

Add a `"discard_play"` event handler alongside the normal `"play_card"` handler. When triggered:
- Skip targeting entirely; use caster as default target
- Call the same effect resolution pipeline with `ap_cost: 0`
- Move the card to discard after resolution

In the HUD, render a secondary "Discard" button on cards with `variant: :discardable`.

### 12. Negative: AP inversion + value negation

**File:** `lib/game/combat/card_effects/apply_variant.ex` — `apply_variant_to_card/3`

At attachment time, invert AP:

```elixir
updated_card = %{card | ap: -card.ap}
```

**File:** `lib/game/card.ex` — effect resolution path

After each effect resolves its final value to an integer, negate it if the card carries
`:negative`. This must happen after formula evaluation, not before:

```elixir
defp apply_resolved_value(value, card) when card.variant == :negative and is_integer(value),
  do: -value
defp apply_resolved_value(value, _card),
  do: value
```

Call `apply_resolved_value/2` immediately after `Game.Formula.resolve/2` returns an integer, before
passing the value into the effect's `process/3`.

**Note:** Non-numeric resolved values (strings, maps, nil) are passed through unchanged — effects
like `summon`, `give`, and `stuck` are unaffected.

### 13. Promo: acquisition gating

**File:** `lib/game/base_cards/base_card.ex`

Add `promo: :boolean, default: false` field. Update `generate_booster_cards_for_class/2` to filter
`where: not c.promo`. Boss/secret drop tables reference promo card IDs directly.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game/card.ex` | Add `variant`, `play_count` fields; echo copy-on-play; signed play-count increment; holographic post-play hook; negative value negation after formula resolution |
| `lib/game/combat/card_effects/apply_variant.ex` | New effect: card-targeting modal + variant application; volatile, widened, and negative attachment-time mutations |
| `lib/game/character.ex` | Foil shuffle priority in draw pile shuffle |
| `lib/game/combat_builder.ex` | Misprint per-combat value mutation |
| `lib/game/base_cards/base_card.ex` | Add `promo` boolean field |
| `priv/repo/migrations/<ts>_add_promo_to_cards.exs` | Migration for `promo` column |
| `lib/game.ex` | Filter promo cards from booster generation |
| `lib/game_web/live/combat_hud.ex` | Discardable secondary play button; visual treatment per variant (border color, badge, shimmer class) |

---

## Open Questions

| Question | Options |
|----------|---------|
| Can a card hold multiple variants? | Probably not — first variant wins, others are discarded. |
| Does a signed card's `play_count` persist across combats in a multi-combat run? | Likely yes — that's the point. Needs a persistence path if combat state is rebuilt between fights. |
| Is the holographic reveal visible to opponents? | Probably not — it's an information advantage, not a debuff. |
| Where do misprint mutations get seeded from? | Combat ID or player seed for reproducibility, or pure random for maximum chaos. |
| How does the card-picker modal for `apply_variant` interact with the existing booster pick UI? | Could reuse the same component with a different mode flag. |

---

## Verification

1. Draft a meta-card (e.g. Foil) from a booster; confirm it appears as a playable card with `apply_variant` effect.
2. Play the meta-card; confirm a card-picker modal opens showing your draw pile.
3. Select a card; confirm it now displays a foil badge and rises to the top of each shuffle.
4. Verify each variant independently against its definition above.
5. Confirm promo cards never appear in booster rolls; confirm they appear in the intended drop table.
6. Confirm a signed card's play count increments each play and its values scale accordingly.
7. Play an echo card; confirm a plain (non-echoing) copy appears in hand immediately after.
8. Apply volatile to `Repent`; confirm AP doubles and `self_destruct` is gone; play it multiple times.
9. Apply widened to `Arcane Explosion`; confirm `range` increments on both the card and its effects.
10. Confirm a discardable card shows a secondary "Discard" button; confirm it triggers effects at 0 AP cost and lands in discard.
11. Apply negative to `Strike` (ap: 1, damage: 3); confirm it now restores 1 AP on play and heals the target for 3.
12. Apply negative to `Snipe` (formula: distance × 2); move 4 tiles away and play it; confirm target is healed for 8.
13. Apply negative to `Blood Magic` (ap: -3); confirm it now costs 3 AP and heals for 3.
14. Confirm non-numeric effects (e.g. `summon`, `stuck`) on a negative card are unaffected.
