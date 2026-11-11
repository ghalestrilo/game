# HexDecks

> Visit https://hexdecks.fly.dev to play

HexDecks is a tactical card-based game. You play as a medieval fantasy character with a deck of cards representing your abilities. Players take turns drawing and playing cards to perform actions - the last team or player surviving wins.

To play you will first need to register an account. This is intentional to prevent server resource abuse, but also to enable multiplayer functionality.
Check your SPAM inbox: your login confirmation email may land there by accident given the current state of the project.

Once authenticated, you can click "Sandbox", pick a map and few classes to start a match - in Sandbox mode you control every character.

To play with other players you will click "Multiplayer" and share an invite to your lobby with other authenticated player(s) - each will then select their match preferences and organize in teams before the match starts.

## Running Locally

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

