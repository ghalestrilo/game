# Feature: DaisyUI Fieldsets

## Context

Two areas need visual grouping with the DaisyUI `fieldset` component
(https://daisyui.com/components/fieldset/):

1. **Card effects** — the per-effect parameter inputs in the admin (`effect_field.ex`)
2. **Lobby settings** — the game settings block in the lobby (`lobby_live.ex`)

DaisyUI fieldset markup:
```html
<fieldset class="fieldset">
  <legend class="fieldset-legend">Legend text</legend>
  <!-- inputs -->
</fieldset>
```

---

## Implementation Plan

### 1. Card effects admin (`effect_field.ex`)

**File:** `lib/game_web/live/admin/fields/effect_field.ex`

The `render_form/1` function currently wraps each parameter in a plain `<div class="flex flex-col gap-1">`. Wrap the whole set of params for one effect in a `<fieldset class="fieldset">` with a legend showing the effect type, and keep each param in a `<label class="fieldset-label">` wrapper per DaisyUI convention.

Replace:
```heex
<div class="flex flex-col gap-2">
  <%= for param <- @params do %>
    <div class="flex flex-col gap-1">
      <label class="label-text text-xs opacity-70">{param}</label>
      ...inputs...
    </div>
  <% end %>
</div>
```

With:
```heex
<fieldset class="fieldset">
  <legend class="fieldset-legend">{effect_type}</legend>
  <%= for param <- @params do %>
    <label class="fieldset-label">{param}</label>
    ...inputs...  <%# unchanged %>
  <% end %>
</fieldset>
```

The `effect_type` variable is already computed at the top of `render_form/1` (line 35).

### 2. Lobby settings (`lobby_live.ex`)

**File:** `lib/game_web/live/lobby_live.ex`

The "Lobby Settings" block (lines 206–298) is currently a plain `<ul>` with `<span>` rows. Wrap it
in a `<fieldset class="fieldset">` with legend "Lobby Settings", and convert each setting row to
use `<label class="fieldset-label">` for its label text.

Replace:
```heex
<ul class="flex flex-col items-start gap-2">
  <h2 class="text-xl font-semibold">Lobby Settings</h2>
  <span class="flex w-full items-center justify-between">
    <label class="text-lg">Booster packs at start:</label>
    ...
  </span>
  ...
</ul>
```

With:
```heex
<fieldset class="fieldset w-full">
  <legend class="fieldset-legend text-xl">Lobby Settings</legend>
  <div class="flex w-full items-center justify-between">
    <label class="fieldset-label">Booster packs at start</label>
    ...  <%# host form / non-host badge unchanged %>
  </div>
  <%# repeat for each setting row %>
</fieldset>
```

The Ready button and status text at the bottom of the block (lines 287–298) sit outside the
settings rows — keep them after the closing `</fieldset>` or in a sibling element.

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game_web/live/admin/fields/effect_field.ex` | Wrap `render_form` output in `<fieldset class="fieldset">` with legend; use `fieldset-label` per param |
| `lib/game_web/live/lobby_live.ex` | Replace `<ul>` + `<h2>` lobby settings block with `<fieldset class="fieldset">` and `fieldset-label` rows |

---

## Verification

1. Open the card admin, edit a card's effect — confirm each effect's params are grouped in a
   labelled fieldset showing the effect type.
2. Open the lobby — confirm the settings block is wrapped in a fieldset labelled "Lobby Settings"
   with each row's label using the fieldset style.
3. Confirm host vs non-host rendering still works (inputs for host, badges for non-host).
