# Feature: Hidden Characters (3D Board)

## Context

The 2D hex board already implements hidden characters correctly:
- Stealthy allies appear desaturated + dimmed (`grayscale opacity-60`)
- Ethereal characters appear desaturated + heavily dimmed (`grayscale opacity-40`)
- Stealthy enemies are hidden entirely (filtered by `visible_to?`)

The 3D Three.js board has the visibility filtering (`visible_to?`) but sends no visual flags to the
frontend — hidden characters appear identical to normal ones. This feature closes that gap.

---

## Implementation Plan

### 1. Pass visual flags from backend to frontend

**File:** `lib/game_web/live/game_board_3d.ex` — `build_characters/2` (line 156)

Extend the character map with `hidden` and `ethereal` flags:

```elixir
defp build_characters(nil, _current_player), do: []

defp build_characters(combat, current_player) do
  combat
  |> Game.CombatState.get_current_queue()
  |> Enum.reject(&is_nil/1)
  |> Enum.filter(&visible_to?(&1, current_player))
  |> Enum.map(fn character ->
    {q, r, s} = character.position

    %{
      id: character.id,
      q: q,
      r: r,
      s: s,
      model_url: model_url(character.class, base_url()),
      team: to_string(character.team),
      hidden: Game.Character.get_status_effect(character, :stealth) != nil,
      ethereal: Game.Character.get_status_effect(character, :ethereal) != nil
    }
  end)
end
```

Enemies with `:stealth` are already excluded by `visible_to?` so they never reach the map — the
`hidden` flag is only ever `true` for allies.

### 2. Apply visual effects in CharacterLayer

**File:** `assets/js/board/character-layer.js` — `sync(characters)` (line 14)

Destructure the new fields and apply material changes whenever `hidden` or `ethereal` changes.
Track current visual state per entry to avoid redundant material updates.

```js
sync(characters) {
  const incoming = new Set(characters.map(c => String(c.id)))

  // Remove characters no longer present (unchanged)
  for (const [id, entry] of this._map) {
    if (!incoming.has(String(id))) {
      if (entry.walkTimer) clearTimeout(entry.walkTimer)
      entry.mixer.stopAllAction()
      this._scene.remove(entry.node)
      this._map.delete(id)
    }
  }

  characters.forEach(({ id, q, r, model_url, hidden, ethereal }) => {
    const { x, y } = hexToWorld(q, r)
    let entry = this._map.get(id)

    if (!entry) {
      this._map.set(id, { pending: true })
      this._assets.loadCharacter(model_url).then(template => {
        if (!this._map.has(id)) return
        const node = cloneSkeleton(template)
        node.userData.characterId = id
        node.rotation.set(Math.PI / 2, 0, 0)
        node.scale.setScalar(0.6)
        node.position.set(x, y, 1)
        this._scene.add(node)

        const mixer = new THREE.AnimationMixer(node)
        const idleAction = mixer.clipAction(this._assets.clips.idle)
        const walkAction = mixer.clipAction(this._assets.clips.walk)
        walkAction.enabled = true
        idleAction.play()

        const newEntry = {
          node, mixer, idleAction, walkAction,
          walkTimer: null,
          moveFrom: new THREE.Vector3(),
          moveTo: new THREE.Vector3(),
          moveProgress: null,
          visualState: null   // track last applied visual state
        }
        this._map.set(id, newEntry)
        applyVisualState(newEntry, hidden, ethereal)

        const center = this.centerOfMass()
        if (this.allNodes().length > 0) this.faceToward(center)
      })
      return
    }

    if (entry.pending) return

    // Apply visual state only when it changes
    const newVisual = hidden ? "hidden" : ethereal ? "ethereal" : "normal"
    if (entry.visualState !== newVisual) {
      applyVisualState(entry, hidden, ethereal)
    }

    // Movement (unchanged)
    const cur = entry.node.position
    const moved = Math.abs(cur.x - x) > 0.001 || Math.abs(cur.y - y) > 0.001
    if (moved) {
      entry.node.rotation.y = Math.atan2(y - cur.y, x - cur.x) + Math.PI / 2
      entry.moveFrom.copy(cur)
      entry.moveTo.set(x, y, 1)
      entry.moveProgress = 0
      entry.walkAction.reset().play()
      entry.walkAction.crossFadeFrom(entry.idleAction, 0.15, true)
      if (entry.walkTimer) clearTimeout(entry.walkTimer)
      entry.walkTimer = setTimeout(() => {
        entry.idleAction.reset().play()
        entry.idleAction.crossFadeFrom(entry.walkAction, 0.2, true)
        entry.walkTimer = null
      }, 500)
    }
  })
}
```

Add the `applyVisualState` helper as a module-level function (outside the class, so it does not
pollute the instance):

```js
function applyVisualState(entry, hidden, ethereal) {
  const visual = hidden ? "hidden" : ethereal ? "ethereal" : "normal"
  entry.visualState = visual

  entry.node.traverse(o => {
    if (!o.isMesh && !o.isSkinnedMesh) return

    // Restore from base material if available, else clone a fresh one
    if (!o.userData.baseMaterial) o.userData.baseMaterial = o.material.clone()
    const mat = o.userData.baseMaterial.clone()

    if (visual === "hidden") {
      // Ally stealth: greyscale + semi-transparent (mirrors 2D `grayscale opacity-60`)
      mat.transparent = true
      mat.opacity = 0.6
      mat.color.set(greyOf(o.userData.baseMaterial.color))
    } else if (visual === "ethereal") {
      // Ethereal: greyscale + heavy transparency (mirrors 2D `grayscale opacity-40`)
      mat.transparent = true
      mat.opacity = 0.4
      mat.color.set(greyOf(o.userData.baseMaterial.color))
    } else {
      // Normal: fully opaque, original color
      mat.transparent = false
      mat.opacity = 1.0
    }

    o.material = mat
  })
}

// Convert a THREE.Color to its luminance-equivalent grey
function greyOf(color) {
  const l = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
  return new THREE.Color(l, l, l)
}
```

Note: when `_onHit` in `ThreeJSBoard.js` flashes an emissive color, it stores `baseMaterial` on the
mesh. `applyVisualState` also uses `baseMaterial` as the source of truth, so they share the same
reference. Hit flashes therefore still work on hidden/ethereal characters.

### 3. Restore visual state after hit flash

**File:** `assets/js/hooks/ThreeJSBoard.js` — `_onHit` handler (line 144)

Currently the hit flash restores `o.userData.baseMaterial` after 300 ms. Since `applyVisualState`
replaces `o.material` with a clone, the restore step (`o.material = o.userData.baseMaterial`) will
put back the *original* fully opaque material on hidden characters. To fix, restore to the *current*
clone (the one with opacity/grey applied) rather than the base:

```js
this._onHit = ({ detail: { id, color } }) => {
  const entry = this._characters.get(Number(id))
  if (!entry) return
  const emissive = HIT_EMISSIVE[color] || HIT_EMISSIVE.yellow
  entry.node.traverse(o => {
    if (!o.isMesh && !o.isSkinnedMesh) return
    if (!o.userData.baseMaterial) o.userData.baseMaterial = o.material.clone()
    // Save the current visual material so we can restore it after the flash
    o.userData.preFashMaterial = o.material
    const flashMat = o.material.clone()
    flashMat.emissive = emissive
    flashMat.emissiveIntensity = 1.0
    o.material = flashMat
  })
  setTimeout(() => {
    entry.node.traverse(o => {
      if ((!o.isMesh && !o.isSkinnedMesh) || !o.userData.preFashMaterial) return
      o.material = o.userData.preFashMaterial
    })
  }, 300)
}
```

---

## Critical Files

| File | Change |
|------|--------|
| `lib/game_web/live/game_board_3d.ex` | Add `hidden:` and `ethereal:` fields in `build_characters/2` |
| `assets/js/board/character-layer.js` | Track `visualState` per entry; call `applyVisualState` on change; add `applyVisualState` and `greyOf` helpers |
| `assets/js/hooks/ThreeJSBoard.js` | Fix `_onHit` to restore `preFashMaterial` instead of `baseMaterial` so opacity/grey survives the hit flash |

No backend logic changes needed — visibility filtering (`visible_to?`) is already correct.

---

## Verification

1. Give a character the `:stealth` status effect (via a stealth card or sandbox).
2. View the 3D board as an **ally** of that character — they should appear grey and semi-transparent
   (~60% opacity), still visible and clickable.
3. View the board as an **enemy** (switch `current_player`) — the stealthy character should not
   appear at all.
4. Apply `:ethereal` — character should appear grey at ~40% opacity for all players.
5. Hit a hidden/ethereal character with a damage card — confirm the red hit flash fires and then
   returns to the grey/transparent state (not a solid opaque material).
6. Wait for stealth duration to expire — confirm the character returns to full color and opacity on
   the next turn.
