# Game
  -
To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## Design

> An open-world couch coop simultaneous roguelike deckbuilding tactical MMORPG with card-based combat

- 1+ players group and explore the world together
- Each player creates a character or picks from a previously created one
- Each character has a deck of cards. This deck is what defines all their abilities in combat
- Combat happens in team turns, each turn all characters in the team are free to move and act in tandem

### Considerations

- There could be a time element to combat which a hexing/debuffing character could exploit
- Slay-the-spire/diceomancer style gameplay

### Data Model

- coordinate: {x,y,z} (hex tiles because hexagons are the bestagons)

### Class mechanics

**Rogue**

- Start with lvl 1 Stealth and Attack cards
  - Stealth: Become invisible until next round. At beginning of next round, scry 3 (then shuffle back):
    - if there's a stealth card, you may cast it for 0 ap cost
    - if there's an attack card, you may cast it for double damage
    - leveling up increases scry
  - Gets many reaction cards - eg. on targeted, attacked or discard events

**Monk**

- Many cards with cycling/scry
- Start with lvl 1 Flurry of blows and Attack cards
  - Flurry of blows: attack w/ effect - scry 3 (then shuffle back):
    - if there's an attack card, you may cast it for double damage
    - leveling up increases scry

**Sorcerer**

- Access to metamagic booster packs

**Mage**

- Many cards with scry
- Many cards with keep - can returns this card to hand once it's been played

**Fighter**

- Some options here
  - +1 hand size
  - +1 AP

**Druid**

## References and resourcess

https://elixirforum.com/t/is-liveview-a-suitable-choice-for-serving-as-a-game-server-for-a-simple-three-js-game/58155/6
https://github.com/5e-bits/5e-database
https://davehardee.com/QRSCoords/



## Current state

- Movement Rules:
  - Characters can move within their movement range
  - Characters cannot move beyond their range
  - Characters cannot move to blocked tiles or tiles occupied by other characters
  - Movement updates the grid and character positions
- Combat Rules:
  - Characters can play cards if they have enough AP
  - Cards can deal damage or heal targets
  - Characters die when their HP reaches 0
  - Dead characters are removed from the game
  - Game ends when only one team remains
- Turn Management:
  - Characters take turns in sequence
  - After an action, the character moves to the end of the queue
  - Dead characters are removed from the turn order
  - The combat module now provides a solid foundation for a card-based turn-based strategy game. The rules are clear and well-tested, covering all the core mechanics needed for the MVP





  https://www.redblobgames.com/grids/hexagons/

## WIP code smells

  1. Card is doing too much (SRP)

  Card is a data struct, but it also owns: effect processing, formula resolution, targeting validation, tile overlay computation, JSON encoding, and animation collection. That's five or six distinct responsibilities. The processing logic (process_card, apply_card_effects, build_tile_overlay, is_target_cell_valid?) belongs in a separate module — something like Game.Combat.CardProcessor or just pushed into Combat/CombatState. Right now, Combat delegates process_card straight back to Card, making the layering circular.

  2. The JSON round-trip is repeated in three places

  build_data_context (line 312–313), build_effect_context (line 158–161), and build_tile_overlay (line 327–328) all do Jason.encode → Jason.decode to produce a plain map for JsonLogic/Formula evaluation. It's the same operation expressed three times. A shared to_plain_map/1 helper would centralize it, and more importantly, build_tile_overlay already encodes combat once and reuses it — but build_data_context (called per-tile from is_target_cell_valid?) re-encodes every call. These two code paths should share the same pre-encoded state.

  3. temporary_hack_filter_only_allowed_effects is duplicating get_structured_effect's logic

  The filter checks whether an effect type is in @effect_types — then get_structured_effect checks the same thing again immediately after. The filter exists to avoid a crash in get_structured_effect for unknown types, but the right fix is to make get_structured_effect return nil for unknowns (it already does) and filter on nil in the reduce, eliminating the pre-pass entirely.

  4. process_action for play_card returns a different shape than all other actions

  Every other action returns {:ok, combat}. play_card returns {:ok, combat, animations}. This breaks the typespec on line 86 and means callers have to know which action they called before they can destructure the result — that's why we needed the play_card/2 helper in tests. A cleaner design: return animations out-of-band (e.g. store them as a field on CombatState that gets cleared each turn, similar to an event log), so all actions keep the same return shape.
  
  5. get_available_card_effects/0 in Combat is out of sync with @effect_types in Card

  There are two separate lists of effect types — one as a map in Card (the source of truth), one as a hardcoded list in Combat.get_available_card_effects/0. Adding a new effect type means updating both. The list function should just delegate to Card.effect_types() |> Map.keys().

  6. build_target_data handles nil and {:ok, nil} as the same case

  The third clause (bare nil, line 391) exists because Grid.get_object can return nil for unknown positions, but the first clause already handles {:ok, nil} for empty tiles. These represent different things — one is "empty tile," the other is "position doesn't exist in the grid" — and conflating them silently masks targeting bugs.

  ---
  The two I'd fix first: the temporary_hack redundancy (easy, low risk) and the inconsistent process_action return shape (higher impact, touches tests but makes the API coherent). The JSON round-trip duplication is real but the performance impact is small at current board sizes.