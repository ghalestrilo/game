# Feature: Booster Card Levels (Experimental)

## Concept

Cards in a booster pool have a `:level` — a gate on how far a player has progressed in deckbuilding
for that class before the card can appear. A level-1 card is always accessible; a level-3 card only
surfaces once the player has collected enough class cards to "unlock" that tier.

The unlock threshold per level is derived from the triangular number sequence —
`threshold(level) = (level - 1) * (level - 2) / 2`:

| Level | Min cards of that class in deck |
|-------|----------------------------------|
| 1     | 0  (always accessible)           |
| 2     | 1                                |
| 3     | 3                                |
| 4     | 6                                |
| 5     | 10                               |
| 6     | 15                               |
| ...   | (n-1)(n-2)/2                     |

Each level costs exactly one more card than the previous, making the curve intuitive without
players needing to know the formula. For a ~10-card starting deck, level 4 (threshold 6) is
reachable from the lobby draft alone; level 6 (threshold 15) is a genuine late-game commitment.
Fibonacci was considered but grows too steeply relative to typical starting deck sizes (level 5
would require 5 additional cards after already needing 3, with a 10-card base).

**Core tension:** unlocking higher-level cards requires holding more class cards in your deck, which
dilutes your draw probability for any given card. You can destroy cards later to sharpen your deck
— but that also risks regressing your level threshold, potentially locking cards you've already
drafted back out of future boosters.

---

## Data Design

Add `:level` as an integer field on `BoosterPoolCard` (the join table introduced in the parent
feature). It is nullable — `nil` means no gate, equivalent to level 1.

```
booster_pool_cards
  pool_id   (FK)
  card_id   (FK)
  count     (integer)   -- probability weight
  level     (integer)   -- minimum deck progression to unlock; nil = always available
```

Level lives on the join row, not on `BaseCard` itself, because the same card could be:
- Level 2 in a Warrior pool (early access, class staple)
- Level 4 in a Mage pool (exotic, late unlock)
- Absent from a Rogue pool entirely

---

## Implementation Plan

### 1. Migration: add `:level` to `booster_pool_cards`

```elixir
alter table(:booster_pool_cards) do
  add :level, :integer
end
```

### 2. Update `BoosterPoolCard` schema

**File:** `lib/game/content/booster_pool_card.ex`

```elixir
field :level, :integer
```

Add `:level` to the `cast` list. No `validate_required` — nil means always accessible.

### 3. Level threshold helper

**File:** `lib/game/content/booster_pool.ex` (or a small `Level` module if it grows)

```elixir
# Returns the minimum number of class cards a player must hold to access this level.
# Triangular sequence: level 1 → 0, level 2 → 1, level 3 → 3, level 4 → 6, level 5 → 10 ...
def level_threshold(nil), do: 0
def level_threshold(level) when is_integer(level) and level >= 1 do
  n = level - 1
  div(n * (n - 1), 2)
end
```

### 4. Count class cards in player deck

**File:** `lib/game.ex` (near `generate_booster_cards_for_class/2`)

At booster generation time, count how many cards in the player's current deck (draw + hand +
discard) have a `base_card_id` that belongs to the chosen class's pool. Starting deck cards drafted
in the lobby count — they are already in `character.cards.draw` when combat begins, giving players
a natural head start toward unlocking their class's higher-level cards.

```elixir
defp count_class_cards(character, pool_card_ids) do
  all_cards = character.cards.draw ++ character.cards.hand ++ character.cards.discard
  Enum.count(all_cards, fn card -> card.base_card_id in pool_card_ids end)
end
```

`pool_card_ids` is the set of `BaseCard` IDs belonging to the chosen class's booster pool — derived
from the preloaded pool when building the booster.

### 5. Filter by level in `generate_booster_cards_for_class/2`

**File:** `lib/game.ex`

After loading the pool (see parent feature plan), filter `booster_pool_cards` before expanding by
count:

```elixir
defp generate_booster_cards_for_class(class, count, character) do
  pool = load_pool_for_class(class)  # preloads booster_pool_cards with card

  pool_card_ids = Enum.map(pool.booster_pool_cards, & &1.card_id) |> MapSet.new()
  progression = count_class_cards(character, pool_card_ids)

  pool.booster_pool_cards
  |> Enum.filter(fn bpc ->
    BoosterPool.level_threshold(bpc.level) <= progression
  end)
  |> Enum.flat_map(fn bpc -> List.duplicate(bpc.card, bpc.count) end)
  |> Enum.shuffle()
  |> Enum.take(count)
  |> Enum.map(&Game.Content.to_game_card/1)
end
```

Pass `character` through from `trigger_class_booster/3` → `generate_booster_cards_for_class/3`.

### 6. Admin UI

**File:** `lib/game_web/live/admin/booster_pool_live.ex`

Add a `level` number input alongside the existing `count` input for each `BoosterPoolCard` row.
Display the computed threshold next to the input for reference (e.g. "requires 5 class cards").

### 7. Card destruction (prerequisite for full loop)

No destruction mechanic exists yet. The feature is playable without it — players can draft and
progress — but destruction is needed for the "prune your deck to sharpen draw odds" half of the
loop.

A minimal destruction mechanic: a "Destroy Card" action available during the booster pick phase
(same modal, extra button per card in hand/draw). Destroying a card:
- Permanently removes it from `character.cards.draw` (or hand)
- Does **not** affect the level threshold retroactively (progression only counts forward — or
  optionally recounts, which adds risk; design decision TBD)

---

## Design Decisions (open)

| Question | Options |
|----------|---------|
| Does destroying a class card reduce progression? | A) Yes — adds risk, sharpens the tension. B) No — progression is a high-water mark. |
| Level cap | Uncapped (triangular growth provides a natural soft cap) or hard cap at level 6–7 (threshold 15–21 cards). |
| Cross-class cards | A card in multiple pools can have different levels per pool (join row), so this is already handled. |
| Fallback when player has no pool cards | Always show level-1 cards only — no special case needed since threshold(1) = 0. |

---

## Critical Files

| File | Change |
|------|--------|
| `priv/repo/migrations/<ts>_add_level_to_booster_pool_cards.exs` | Add `:level` integer column |
| `lib/game/content/booster_pool_card.ex` | Add `:level` field + cast |
| `lib/game/content/booster_pool.ex` | Add `level_threshold/1` helper |
| `lib/game.ex` | Add `count_class_cards/2`; update `generate_booster_cards_for_class` to accept character + filter by level |
| `lib/game_web/live/admin/booster_pool_live.ex` | Add level input + threshold display |

---

## Verification

1. Create a pool with cards at levels 1, 2, and 4 (thresholds: 0, 1, 3 class cards).
2. Start a combat with an empty deck; step on a booster tile.
3. Confirm only level-1 cards appear in the pack.
4. Draft 1 class card; trigger another booster.
5. Confirm level-1 and level-2 cards appear; level-4 cards do not.
6. Draft until you hold 3 class cards; confirm level-4 cards now appear.
7. (Once destruction exists) Destroy 2 class cards; confirm level-4 cards disappear from the pool
   if progression is tracked dynamically, or remain if using high-water mark.
