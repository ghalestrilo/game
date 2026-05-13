# status-effect-ui

Add or change the visual representation of a status effect on the game board and/or the HUD queue.

## Architecture overview

Status effect visuals live in three places:

| What | File | Purpose |
|---|---|---|
| `StatusEffect.icon_for/1` | `lib/game/combat/status_effect.ex` | Maps type atom → heroicon name |
| `StatusEffect.kind/1` | `lib/game/combat/status_effect.ex` | Returns `:buff`, `:debuff`, or `:neutral` |
| `StatusEffect.badge_class/1` | `lib/game/combat/status_effect.ex` | Maps kind → DaisyUI badge color class |
| Board token badges | `lib/game_web/live/game_board.ex` | Icon badges on the character sprite |
| Shield pulse overlay | `lib/game_web/live/game_board.ex` | Blue `animate-pulse` overlay div |
| HUD text badges | `lib/game_web/live/combat_hud.ex` | Text badges in the queue card sidebar |

The board token and HUD are independent — changes to one don't affect the other.

## Step 1 — Assign an icon

In `lib/game/combat/status_effect.ex`, add a clause to `icon_for/1` before the fallback:

```elixir
def icon_for(:<type>), do: "hero-<heroicon-name>-solid"
```

Browse heroicons at heroicons.com. Prefer `-solid` for filled badges, `-mini` for very small inline icons.

## Step 2 — Assign a kind (buff / debuff / neutral)

In the same file, add a clause to `kind/1` before the fallback:

```elixir
def kind(:<type>), do: :buff     # green badge-success
# or
def kind(:<type>), do: :debuff   # red   badge-error
# or
def kind(:<type>), do: :neutral  # blue  badge-info
```

`badge_class/1` is derived from `kind/1` automatically — no separate change needed.

**Classification guide:**
- `:buff` — positive effects the caster applies to themselves or allies (shield, regen, stealth, ethereal)
- `:debuff` — negative effects applied to enemies (dot, stun, hex, slow, stuck)
- `:neutral` — stat modifications, informational, or ambiguous (modify_attribute)

## Step 3 — Special board overlays (optional)

For visually prominent statuses (like shield), you can add a full-token overlay div inside the character element in `lib/game_web/live/game_board.ex`:

```heex
<div
  :if={Game.Character.get_status_effect(character, :<type>) != nil}
  class="absolute inset-0 rounded-full bg-<color>/30 animate-pulse pointer-events-none"
/>
```

Place it before the badge `<span>` loop. The existing shield overlay uses `bg-info/60 animate-pulse`.

For filter-based visuals (like stealth's grayscale), edit `character_filter_class/2` in the same file:

```elixir
defp character_filter_class(character, current_player) do
  cond do
    Game.Character.get_status_effect(character, :<type>) != nil ->
      "your-tailwind-classes"
    # existing clauses ...
  end
end
```

## Step 4 — HUD text badges (optional)

The queue card sidebar (`lib/game_web/live/combat_hud.ex`) renders a text badge for every non-shield effect via `Game.StatusEffect.get_display_text/1`. To change display text, edit the matching clause in `get_display_text/1` in `lib/game/combat/status_effect.ex`:

```elixir
def get_display_text(%{type: :<type>, value: v}) do
  "Your custom label"
end
```

The generic fallback (`String.capitalize(type) <> " (field:value...)"`) is used when no specific clause matches.

The shield effect is excluded from the text badges (it has its own pip bar). To similarly exclude a new effect from the text list, add its type to the reject filter in `combat_hud.ex`:

```elixir
:for={effect <- Enum.reject(@character.status_effects, &(&1.type in [:shield, :<your_type>]))}
```

## Verification

1. `mix compile` — no errors
2. Start the server and give a character the effect via sandbox or a test card
3. Check the board token: icon badge should appear with the correct color
4. Check the HUD queue card: text badge should appear (or be absent if excluded)
5. Check that buff icons are green, debuff icons are red, neutral are blue

## File summary

- `lib/game/combat/status_effect.ex` — `icon_for/1`, `kind/1`, `badge_class/1`, `get_display_text/1`
- `lib/game_web/live/game_board.ex` — board token badges (`:for` loop), overlay divs, `character_filter_class/2`
- `lib/game_web/live/combat_hud.ex` — HUD text badges, shield pip bar
