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
