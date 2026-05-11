# admin-content

Create, modify, or sync game content — cards, decks, and character classes — using the admin content system.

## Content architecture overview

All game content lives in the database, not in code. The hierarchy is:

```
BaseCard         — a card definition (name, cost, range, effects, rarity, targeting)
  └─ embedded: [Effect]   — list of effects with type, value, range, etc.

BaseDeck         — a named collection of cards
  └─ BaseDeckCard (join)  — card_id + count (how many copies in the deck)

BaseClass        — a playable character class
  ├─ class: string        — slug used in URLs and lobby ("fighter", "mage")
  ├─ deck_id              — which BaseDeck they start with
  └─ strategy_id          — AI behaviour (nil = human-controlled)

FormulaAlias     — named reusable formula (expanded by Game.Formula.resolve/2)
Strategy + Tactic — AI behaviour tree
```

At runtime, `Game.CombatBuilder.build/1` loads the class → deck → cards chain and converts it to in-memory `%Game.Character{}` / `%Game.Card{}` structs.

## Creating a new card

### Via Ecto (code / seeds)

```elixir
{:ok, card} = Game.BaseCards.create_base_card(%{
  name: "Frost Nova",
  headline: "Freezes all nearby enemies",
  ap: 2,          # action point cost (becomes card.cost at runtime)
  range: 1,       # targeting range in hex tiles
  rarity: :common,  # :common | :uncommon | :rare | :legendary
  effects: [
    %{
      type: "slow",       # must be a key in Game.Card.@effect_types
      value: "2",         # stored as string, parsed to int at runtime
      value_label: "2 turns"
    }
  ],
  # Optional: targeting rule (JsonLogic, evaluated at target-selection time)
  targeting: %{
    "type" => "character",   # or "tile"
    "rule" => %{"!=" => [%{"var" => "target.team"}, %{"var" => "state.combat.current_turn.player.team"}]}
  }
})
```

**Valid effect types** (from `Game.Card.@effect_types`):
`damage`, `heal`, `draw`, `discard`, `shield`, `summon`, `stealth`, `stuck`, `slow`, `stun`, `move`, `dot`, `regen`, `cleanse`, `ethereal`, `hex`, `self_destruct`, `give`, `modify_attribute`

**Effect value can be a JsonLogic formula map** instead of a string — see `/formula-debug` for the formula system.

**Multi-param effects** need extra keys in the effect map:
```elixir
# DoT: value = duration (turns), damage = damage per turn
%{type: "dot", value: "3", damage: "5", value_label: "5/turn"}

# Modify attribute: attribute name + value + optional duration
%{type: "modify_attribute", attribute: "max_hp", value: "10", duration: nil}

# Move: angle (hex direction 0–5) + distance
%{type: "move", angle: %{"var" => "angle_push_from_blast"}, distance: "2"}
```

### Via admin UI

Navigate to `/admin/base-cards` in the running app. The LiveView form handles effects as embedded schemas with formula editors.

## Adding a card to a deck

```elixir
alias Game.{Repo, Content.BaseDeckCard}

# Find the deck and card
deck = Repo.get_by!(Game.BaseDecks.BaseDeck, name: "Fighter Starter")
card = Repo.get_by!(Game.BaseCards.BaseCard, name: "Frost Nova")

# Add 2 copies to the deck
Repo.insert!(%BaseDeckCard{deck_id: deck.id, card_id: card.id, count: 2})
```

Or via admin UI at `/admin/base-decks` — the deck editor lets you add/remove cards with counts.

## Creating a new character class

```elixir
alias Game.{Repo, Content.BaseClass}

deck = Repo.get_by!(Game.BaseDecks.BaseDeck, name: "My Deck")

Repo.insert!(%BaseClass{
  class: "ranger",        # slug — must be lowercase, no spaces
  base_hp: 18,
  base_ap: 3,
  base_movement: 3,
  deck_id: deck.id,
  strategy_id: nil,       # nil = human-controlled; set to a Strategy id for AI
  avatar_url: nil         # optional image URL
})
```

To make the class selectable in the lobby, it must also be returned by `Game.Content.list_playable_classes/0` — check `lib/game/content.ex` for the query; it returns all `BaseClass` records.

## Verifying content loads correctly

```elixir
# In iex -S mix

# Load the class as it would be loaded during combat initialization
base_class = Game.Content.get_base_class_by_class!("ranger")
char = Game.Character.from_character_data(base_class)

# Inspect the resulting deck
IO.puts("Deck size: #{length(char.cards.draw)}")
IO.puts("Hand size config: #{char.hand_size}")
Enum.each(char.cards.draw, &IO.puts("  #{&1.name} (cost #{&1.cost})"))

# Verify a card's effects resolve at runtime
card = hd(char.cards.draw)
effect = hd(card.effects)
IO.inspect(Game.Card.get_structured_effect(effect), label: "Effect struct")
```

## Content sync (dev ↔ production)

**Push local → production:**
```bash
mix game.push_content_sync
```
This clears the prod DB content tables and re-inserts everything from the local dev DB, remapping IDs. Run it after making content changes in dev that should go to prod.

**Pull production → local** (currently outdated — missing Strategy + FormulaAlias sync):
```bash
mix game.pull_content_sync
```
If the pull task is needed, note that it needs updating to match the push task's scope: it should also sync `formula_aliases` and `strategies` tables.

**What gets synced** (push direction):
1. `FormulaAlias` — named formula expressions
2. `Strategy` + `Tactic` — AI behaviour definitions
3. `BaseCard` + embedded `Effect` — card definitions
4. `BaseDeck` — deck definitions
5. `BaseDeckCard` — deck-card join records with counts
6. `BaseClass` — character class definitions with foreign keys remapped

**What does NOT get synced**: game state, player accounts, lobby history — those are runtime-only.

## Common mistakes

- **Effect type not registered**: if you create a card with a new effect type, you must also add it to `@effect_types` in `lib/game/card.ex` and implement the `Game.Combat.CardEffect` protocol — see `/card-effect`
- **Rarity atom vs string**: the DB stores rarity as an atom enum (`:common`, not `"common"`). When building maps for `create_base_card`, pass the atom.
- **Deck not preloaded**: `Repo.get!(BaseDeck, id)` does NOT preload `base_deck_cards` or cards. Use `Repo.preload(deck, [base_deck_cards: :card])` or rely on `Game.Character.from_character_data/1` which does this internally.
- **Class slug collision**: `class` must be unique. Check with `Repo.get_by(BaseClass, class: "name")` before inserting.
- **Effects stored as strings**: the `value` field in the embedded `Effect` schema is a `StringOrNumber` type — it accepts strings, integers, or maps. Store numeric values as strings (`"5"`) if coming from form input; the runtime converts them via `Integer.parse/1` in `Game.Card.get_structured_effect/1`.
