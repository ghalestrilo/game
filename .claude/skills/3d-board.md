# 3d-board

Modify the Three.js game board — tile rendering, character animation, hit/float effects, highlights, camera, and asset loading.

## Architecture

The board is a Phoenix LiveView hook (`ThreeJSBoard`) that delegates to four modules:

| Module | File | Responsibility |
|--------|------|---------------|
| `AssetLoader` | `assets/js/board/asset-loader.js` | Loads GLTF tiles, objects, characters, and animation clips |
| `TileLayer` | `assets/js/board/tile-layer.js` | Syncs hex tile meshes, object meshes, and emissive highlights |
| `CharacterLayer` | `assets/js/board/character-layer.js` | Syncs character models, drives walk/idle animation and lerp movement |
| `BoardCamera` | `assets/js/board/board-camera.js` | Orbit/pan/zoom camera controls |
| `hex-utils.js` | `assets/js/board/hex-utils.js` | `hexToWorld`, `meshesOf`, `matteify`, `HIGHLIGHT_COLORS` |

`ThreeJSBoard` (`assets/js/hooks/ThreeJSBoard.js`) owns the render loop, hit flash, floating labels, click raycasting, and hover blast highlights.

## Coordinate system

Hex cube coords `{q, r, s}` → world XY via `hexToWorld(q, r)`:
```js
x =  HEX_SIZE * (3/2 * q)
y = -HEX_SIZE * (√3/2 * q + √3 * r)
```
`HEX_SIZE = 1.1`. Z = 0 for tiles, Z = 1 for characters.

## Character animation

Each character entry in `CharacterLayer._map`:
```js
{ node, mixer, idleAction, walkAction, walkTimer, moveFrom, moveTo, moveProgress }
```

**On spawn:** `idleAction.play()` — character loops idle immediately.

**On move** (position changed in `sync()`):
```js
entry.walkAction.reset().play()
entry.walkAction.crossFadeFrom(entry.idleAction, 0.15, true)  // blend into walk
setTimeout(() => {
  entry.idleAction.reset().play()
  entry.idleAction.crossFadeFrom(entry.walkAction, 0.2, true) // blend back to idle
  entry.walkTimer = null
}, 500)
```
**Key rule:** always call `.reset().play()` on the *target* action before calling `crossFadeFrom` — the target must be active for Three.js to blend into it. Calling `crossFadeTo` with an inactive target causes a snap to bind pose.

**Position lerp:** `moveProgress` goes 0→1 over `WALK_DURATION = 0.3s` via `lerpVectors` in `update(delta)`.

## Adding a new animation

1. Add a new clip entry in the asset config passed to `ThreeJSBoard` (server-side):
   ```elixir
   animations: %{my_anim: %{url: "/path/to.glb", clip: "ClipName"}}
   ```
2. Access it in `CharacterLayer` via `this._assets.clips.my_anim`
3. Create the action: `mixer.clipAction(this._assets.clips.my_anim)`
4. Crossfade using the same pattern as walk: target `.reset().play()` first, then `crossFadeFrom`

## Tile highlights

Highlights come from two sources:

| Source | How set |
|--------|---------|
| Server (movement range, player pos) | `serverHighlight` field on each tile entry, set during `TileLayer.sync()` |
| Client (hover, blast preview) | `TileLayer.applyHighlights(hoveredCoord, blastMap)` called on pointer move |

`HIGHLIGHT_COLORS` in `hex-utils.js`:
```js
movement: 0xf59e0b  // amber
player:   0x22c55e  // green
valid:    0xef4444  // red (target selection)
invalid:  0x6b7280  // gray
blast:    0x991b1b  // dark red
```

All tinting is emissive (`o.material.emissive` + `emissiveIntensity`). Base materials are cached on `userData.baseMaterial` so they can be restored.

## Hit flash & floating labels

Both are driven by Phoenix push events from the server:

**Hit flash** (`phx:hit`): sets emissive color on all meshes of the character node for 300ms, then restores base materials.

**Float label** (`phx:float`): creates a `CSS2DObject`, positions it above the character in world space, animates opacity to 0 over 0.9s via the render loop `_activeFloats` array.

## Asset loading

`AssetLoader.load(assets)` takes a map of:
```js
{
  tiles:       { default: "/path/tile.glb" },
  game_objects:{ default: "/path/wall.glb" },
  characters:  { default: "/path/character.glb" },
  animations:  { idle: { url: "/path/anims.glb", clip: "Idle_A" },
                 walk: { url: "/path/anims.glb", clip: "Walk_A" } }
}
```
Characters can also be loaded on-demand per-character via `loadCharacter(url)` (caches by URL). This supports per-player custom models.

## Common mistakes

- **Snap to bind pose on animation transition**: always call `targetAction.reset().play()` *before* `crossFadeFrom(sourceAction)`. The source action gets disabled; the target must already be active.
- **`crossFadeTo` vs `crossFadeFrom`**: prefer `crossFadeFrom` on the target (new) action — it's clearer which action is taking over.
- **Raycasting characters**: use `meshesOf(node, { skinned: true })` — skinned meshes require the `skinned` flag to be included in intersection tests.
- **`userData.coord`** is the string key `"q_r_s"` on tile nodes. **`userData.characterId`** is the numeric id on character nodes. Walk parent chain to find these when raycasting into deep mesh hierarchies.
- **`matteify`**: always call on tile/object GLTF scenes after load — removes specular highlights that look wrong on the flat-lit board style.
