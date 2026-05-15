# add-3d-model

Add a new 3D model (tile variant, map object, or animated character) to the 3D combat board.

## What you need from the user

1. **Model type** — tile variant, map object (placed on a tile), or character
2. **Asset path in the Tigris bucket** — e.g. `characters/Warrior.glb` (relative to the base URL)
3. **Animation GLB** (characters only) — which animation file and clip name to use by default

## Key files

| File | Role |
|---|---|
| `assets/js/hooks/ThreeJSBoard.js` | Production 3D board hook — all scene logic lives here |
| `assets/js/hooks/ThreeJS.js` | Prototype/sandbox hook — mirror changes here too |
| `lib/game_web/live/game_board_3d.ex` | LiveComponent — pushes `init` (assets) and `board_state` to the hook |

## Serving assets

Assets are served from Tigris object storage. The base URL is configured via `ASSETS_BASE_URL` env var (dev default in `config/dev.exs`). The subpath `/hexdecks/assets` is appended automatically by `default_assets/0` in `game_board_3d.ex`.

To add a new asset, upload it to the Tigris bucket under the appropriate subfolder (`tiles/`, `objects/`, `characters/`, `animations/`) and add its key to `default_assets/0`:

```elixir
defp default_assets do
  base = Application.get_env(:game, :assets_base_url, "") |> String.trim_trailing("/")
  base = "#{base}/hexdecks/assets"
  %{
    tiles:       %{default: "#{base}/tiles/hex_forest_detail.gltf.glb",
                   snow:    "#{base}/tiles/hex_snow.glb"},       # ← new variant
    game_objects: %{default: "#{base}/objects/detail_treeA.gltf.glb"},
    characters:   %{default: "#{base}/characters/Mage.glb",
                    warrior: "#{base}/characters/Warrior.glb"},  # ← new character
    animations:   %{idle: %{url: "#{base}/animations/Rig_Medium_General.glb",      clip: "Idle_A"},
                    walk: %{url: "#{base}/animations/Rig_Medium_MovementBasic.glb", clip: "Walking_A"}}
  }
end
```

The hook receives this map via the `init` event and loads all URLs automatically — **no hook code changes needed** to add new keys to existing categories.

## How the hook loads assets

`handleEvent("init", ...)` iterates each category and loads all URLs with `GLTFLoader`, storing results in keyed registries:
- `this._tileTemplates`      — key → `THREE.Group` (plain `.clone()`)
- `this._objectTemplates`    — key → `THREE.Group` (plain `.clone()`)
- `this._characterTemplates` — key → `THREE.Group` (**must use `cloneSkeleton()`**)
- `this._animationClips`     — key → `THREE.AnimationClip`

Tile and object templates have `matteify()` called on load (`roughness=1, metalness=0`) to remove reflections.

`Promise.all(loads)` gates all rendering — `board_state` is buffered until every asset resolves.

## Model type patterns

### Tile variant

Hook already handles multiple tile keys via `this._tileTemplates[tileKey]`. To use a non-default tile for specific terrain, pass a `tile` key in the tile payload from the server:

```elixir
%{q: q, r: r, s: s, tile: "snow", has_object: wall?(tile), highlight: highlight}
```

Then in `_syncTiles`:
```js
const tileTemplate = this._tileTemplates[tile] || this._tileTemplates.default
```

### Map object

Same pattern as tile variant — add the key to `game_objects` in `default_assets/0`, pass `object_type` from server, look up `this._objectTemplates[object_type]` in `_syncTiles`. Object nodes are stored alongside `tileNode` in `_tileMap` so they're removed together.

### Animated character

Characters **must** use `cloneSkeleton()` (from `three/examples/jsm/utils/SkeletonUtils.js`), NOT `.clone()`. Plain `.clone()` leaves `SkinnedMesh` bones pointing at the template skeleton (not in the scene) → model is invisible.

```js
const node = cloneSkeleton(this._characterTemplates.default)
node.rotation.set(Math.PI / 2, 0, 0)
node.scale.setScalar(0.6)
const mixer = new THREE.AnimationMixer(node)
const idleAction = mixer.clipAction(this._animationClips.idle)
const walkAction = mixer.clipAction(this._animationClips.walk)
idleAction.play()
```

**Animation crossfade pattern** — use `crossFadeFrom` on the destination, not `crossFadeTo` on the source. The source-based API leaves the source in a disabled state that `.play()` alone can't fully recover:
```js
// To walk:
entry.walkAction.reset().play()
entry.walkAction.crossFadeFrom(entry.idleAction, 0.15, true)

// Back to idle:
entry.idleAction.reset().play()
entry.idleAction.crossFadeFrom(entry.walkAction, 0.2, true)
```

**Walking on move** — detect position change, face target, crossfade, lerp position over `WALK_DURATION` seconds:
```js
if (moved) {
  entry.node.rotation.y = Math.atan2(y - cur.y, x - cur.x) + Math.PI / 2
  entry.moveFrom.copy(cur)
  entry.moveTo.set(x, y, 1)
  entry.moveProgress = 0
  entry.walkAction.reset().play()
  entry.walkAction.crossFadeFrom(entry.idleAction, 0.15, true)
  clearTimeout(entry.walkTimer)
  entry.walkTimer = setTimeout(() => {
    entry.idleAction.reset().play()
    entry.idleAction.crossFadeFrom(entry.walkAction, 0.2, true)
  }, WALK_DURATION * 1000)
}
```

The render loop advances `moveProgress` and calls `lerpVectors`.

**Cleanup**:
```js
if (entry.walkTimer) clearTimeout(entry.walkTimer)
entry.mixer.stopAllAction()
this._scene.remove(entry.node)
```

## Available animation clips

`Rig_Medium_General.glb`: `Death_A`, `Death_B`, `Hit_A`, `Hit_B`, `Idle_A`, `Idle_B`, `Interact`, `PickUp`, `Spawn_Air`, `Spawn_Ground`, `Throw`, `Use_Item`

`Rig_Medium_MovementBasic.glb`: `Walking_A`, `Walking_B`, `Walking_C`, `Running_A`, `Running_B`, `Jump_Full_Long`, `Jump_Full_Short`, `Jump_Idle`, `Jump_Start`, `Jump_Land`

These rigs target the Medium humanoid skeleton (`Rig_Medium`). New characters sharing this skeleton can reuse these animation files.

## Tile highlight system

Tiles are tinted via `_tintNode(node, color, intensity)` which clones the base material and sets `emissive`. Base materials are cached on `o.userData.baseMaterial` the first time.

Server-assigned highlights are stored on `tileNode.userData.serverHighlight` (a string key). Hover and blast highlights are applied client-side in `_applyBlastHighlight()`, which runs on every `pointermove` and `board_state` update. Priority order:

1. **Hovered tile** — bright red (`valid`, intensity 0.9)
2. **Blast tiles** (from `blast_map` for hovered coord) — dark red (`blast` `0x991b1b`, intensity 0.7)
3. **Server highlight** — movement (amber), player (green), valid (red), invalid (gray) at intensity 0.5
4. **No highlight** — base material restored

`blast_map` is sent in `board_state` as `%{"q_r_s" => ["q_r_s", ...]}` and stored in `this._blastMap`.

## Coordinate system

The scene is **Z-up**: the hex board sits in the **XY plane**, Z is the vertical axis. `camera.up = (0,0,1)` and `OrbitControls` is configured accordingly.

```js
const HEX_SIZE = 1.1
x = HEX_SIZE * (3/2 * q)
y = -HEX_SIZE * (√3/2 * q + √3 * r)   // negated: map r increases downward, world Y increases upward
z = 0                                   // board surface; objects sit above this
```

All GLB assets are authored Y-up:
- **Tiles / map objects** — `rotation.set(Math.PI / 2, Math.PI / 6, 0)`: lays flat in XY, aligns to hex grid
- **Characters** — `rotation.set(Math.PI / 2, 0, 0)`: stands upright along Z; yaw via `rotation.y`

`OrbitControls`:
```js
camera.up.set(0, 0, 1)          // must be set BEFORE constructing OrbitControls
controls.minPolarAngle = 0
controls.maxPolarAngle = Math.PI / 2 - 0.05
```

Camera pans to the active character on turn change: `_cameraTarget` is set in `_applyBoardState` when `current_turn_id` changes; the render loop lerps `controls.target` and shifts `camera.position` by the same delta to preserve zoom/angle.

## Common mistakes

- **Invisible skinned mesh** — used `.clone()` instead of `cloneSkeleton()`. All meshes show `visible: true` and `has texture` in console but nothing renders.
- **Animation snaps to T-pose on return** — used `crossFadeTo` on the source instead of `crossFadeFrom` on the destination. The source ends up disabled; `play()` alone can't recover it.
- **Assets not loading** — `ASSETS_BASE_URL` not set or wrong. Check `Application.get_env(:game, :assets_base_url)` in iex, verify network requests in browser devtools.
- **CORS error on GLB fetch** — Tigris bucket must allow the app's origin. `GLTFLoader` fetches via `fetch()` from the browser, subject to CORS.
- **Camera flips when tilting** — `camera.up` must be set to `(0,0,1)` *before* constructing `OrbitControls`. Setting it after has no effect.
- **Character faces wrong direction** — yaw is `rotation.y` (after X-rotation). `atan2(dy, dx) + Math.PI / 2` corrects for the model's +Y local forward.
- **New asset key ignored** — adding a key to `default_assets/0` is enough for the hook to load it; no hook code changes needed. But the key must be referenced somewhere in `_syncTiles` or `_syncCharacters` to actually be used in the scene.
