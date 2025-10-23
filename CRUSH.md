# CRUSH.md - Development Guide

## Commands

- **Setup**: `mix setup` (install deps, setup DB, build assets)
- **Server**: `mix phx.server` or `iex -S mix phx.server`
- **Test all**: `mix test`
- **Test single file**: `mix test test/path/to/file_test.exs`
- **Test single test**: `mix test test/path/to/file_test.exs:LINE_NUMBER`
- **Format**: `mix format`
- **DB reset**: `mix ecto.reset`
- **Assets build**: `mix assets.build`

## Code Style

- **Formatting**: Use `mix format` - configured in `.formatter.exs` with Phoenix/Ecto imports
- **Moduledocs**: Add `@moduledoc` to all modules explaining purpose and architecture
- **Aliases**: Group aliases by category (Game.*, GameWeb.*, Phoenix.*)
- **Pattern matching**: Prefer pattern matching over conditionals
- **Pipe operator**: Use `|>` for data transformations
- **Naming**: snake_case for functions/variables, PascalCase for modules
- **Structs**: Use structs with `@enforce_keys` for domain models (Character, Card, Grid, etc.)
- **Testing**: Use ExUnit with `async: true` when possible, setup blocks for test data
- **Fixtures**: Use `Game.Fixtures` module for test data (mage, warrior, cards)

## Architecture

- **Combat**: `Game.Combat` coordinates actions, `Game.CombatState` handles state mutations
- **LiveView**: State in assigns (`:game_pid`, `:game_state`, `:action_log`, `:modal`)
- **Grid**: Hex coordinates as `{q, r, s}` tuples, use `Game.Grid` for operations
- **Cards**: Effects as tuples like `{:damage, 5}`, `{:heal, 3}`
- **GenServer**: Game state managed via GenServer (`:set_state`, `:get_state` calls)
