# add-3d-model

Add a new 3D model (tile variant, map object, or animated character) to the 3D combat board.

## What you need from the user

1. **Model type** — tile variant, map object (placed on a tile), or character
2. **GLB file path** — e.g. `assets/3d/tiles/hex_snow.glb` or `assets/3d/characters/Warrior.glb`
3. **Animation GLB** (characters only) — separate animation GLB files if any; ask what animation to play by default

## Key files

| File | Role |
|---|---|
| `assets/js/hooks/ThreeJSBoard.js` | Production 3D board hook — all scene logic lives here |
| `assets/js/hooks/ThreeJS.js` | Prototype/sandbox hook — mirror changes here too |
| `lib/game_web/live/game_board_3d.ex` | LiveComponent that pushes `board_state` to the hook |
| `priv/static/3d/` | Served static assets — GLBs must be copied here |
| `lib/game_web.ex` | `static_paths/0` — must include `"3d"` (already done) |

## Serving the asset

Always copy new GLBs from `assets/3d/` to `priv/static/3d/` before use — Phoenix serves `priv/static/` directly:

```sh
cp assets/3d/<path>/model.glb priv/static/3d/<path>/model.glb
```

`priv/static/3d/` is already in `static_paths/0` in `lib/game_web.ex` — no change needed there.

## Model types and patterns

### Tile variant

A tile is a flat hex surface placed at every `(q, r)` coordinate. Tiles use `.clone()` (no skeleton).

**Hook changes** (`ThreeJSBoard.js`):
1. Add a template field: `this._snowTileTemplate = null`
2. Load it: `loader.load("/3d/tiles/hex_snow.glb", gltf => { this._snowTileTemplate = gltf.scene; onModelLoaded() })`
3. Increment the `onModelLoaded` gate count
4. In `_syncTiles`, choose which template based on tile data:
   ```js
   const template = tile.terrain === "snow" ? this._snowTileTemplate : this._tileTemplate
   const tileNode = template.clone()
   tileNode.position.set(x, y, 0)
   tileNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
   ```

**Server changes** (`game_board_3d.ex`):
Pass `terrain` in the tile payload so the hook can differentiate:
```elixir
%{q: q, r: r, s: s, terrain: tile.terrain, has_object: wall?(tile), highlight: highlight}
```

### Map object

A map object sits on top of a tile (tree, chest, wall decoration). Also uses `.clone()`.

**Hook changes**:
1. Add template + load it (same pattern as tile variant above)
2. In `_syncTiles`, check `tile.has_object` (or a specific object type field) and clone:
   ```js
   if (has_object) {
     const objNode = this._treeTemplate.clone()
     objNode.scale.set(3, 3, 3)
     objNode.position.set(x, y, 0.9)   // z lifts it above the tile surface
     objNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
     this._scene.add(objNode)
   }
   ```
3. Store in `_tileMap` entry alongside `tileNode` so it gets removed when the tile does.

**Server changes**: pass an `object_type` string in the tile payload if you need to distinguish multiple object types.

### Animated character

Characters use `SkeletonUtils.clone()` (NOT `.clone()`) because they have `SkinnedMesh` nodes whose bones must be rewired per instance. Plain `.clone()` produces an invisible model — the bones remain pointing at the template's skeleton which isn't in the scene.

**Hook changes**:

```js
import { clone as cloneSkeleton } from "three/examples/jsm/utils/SkeletonUtils.js"
```

Load the mesh GLB and one or more animation GLBs separately:
```js
loader.load("/3d/characters/Warrior.glb", gltf => { this._warriorTemplate = gltf.scene; onModelLoaded() })
loader.load("/3d/characters/Rig_Medium_General.glb", gltf => {
  this._idleClip = THREE.AnimationClip.findByName(gltf.animations, "Idle_A")
  onModelLoaded()
})
loader.load("/3d/characters/Rig_Medium_MovementBasic.glb", gltf => {
  this._walkClip = THREE.AnimationClip.findByName(gltf.animations, "Walking_A")
  onModelLoaded()
})
```

Spawn with `cloneSkeleton`, attach a mixer, and play the default clip:
```js
const node = cloneSkeleton(this._warriorTemplate)
node.rotation.set(Math.PI / 2, 0, 0)   // stand upright in this scene's coordinate system
node.scale.setScalar(0.6)               // tune to match tile scale
const mixer = new THREE.AnimationMixer(node)
const idleAction = mixer.clipAction(this._idleClip)
const walkAction = mixer.clipAction(this._walkClip)
idleAction.play()
```

Call `mixer.update(delta)` every frame in the render loop (already done in `ThreeJSBoard.js`).

**Walking animation on move** — detect position change, face the target, crossfade, then return to idle:
```js
const moved = Math.abs(cur.x - x) > 0.001 || Math.abs(cur.y - y) > 0.001
if (moved) {
  node.rotation.y = Math.atan2(y - cur.y, x - cur.x) + Math.PI / 2

  // Lerp position over WALK_DURATION seconds (defined at top of hook, default 0.5)
  entry.moveFrom.copy(cur)
  entry.moveTo.set(x, y, zOffset)
  entry.moveProgress = 0

  entry.walkAction.reset().play()
  entry.idleAction.crossFadeTo(entry.walkAction, 0.15, true)
  clearTimeout(entry.walkTimer)
  entry.walkTimer = setTimeout(() => {
    entry.walkAction.crossFadeTo(entry.idleAction, 0.2, true)
    entry.idleAction.play()
  }, WALK_DURATION * 1000)
}
```

The render loop advances `moveProgress` and calls `lerpVectors` — see existing implementation in `ThreeJSBoard.js`.

**Cleanup** — always stop the mixer and clear timers when removing a character:
```js
if (entry.walkTimer) clearTimeout(entry.walkTimer)
entry.mixer.stopAllAction()
this._scene.remove(entry.node)
```

## Available animation clips

`Rig_Medium_General.glb`: `Death_A`, `Death_B`, `Hit_A`, `Hit_B`, `Idle_A`, `Idle_B`, `Interact`, `PickUp`, `Spawn_Air`, `Spawn_Ground`, `Throw`, `Use_Item`

`Rig_Medium_MovementBasic.glb`: `Walking_A`, `Walking_B`, `Walking_C`, `Running_A`, `Running_B`, `Jump_Full_Long`, `Jump_Full_Short`, `Jump_Idle`, `Jump_Start`, `Jump_Land`

These rigs are designed for the Medium humanoid skeleton (`Rig_Medium`). New character GLBs that share this skeleton can use the same animation files.

## Coordinate system

The scene is **Z-up**: the hex board sits in the **XY plane**, Z is the vertical axis. `camera.up = (0,0,1)` and `OrbitControls` is configured accordingly.

Hex axial coords map to world XY:
```js
const HEX_SIZE = 1.1
x = HEX_SIZE * (3/2 * q)
y = -HEX_SIZE * (√3/2 * q + √3 * r)   // negated: map r increases downward, world Y increases upward
z = 0                                   // board surface; objects sit above this
```

All GLB assets are authored Y-up. To place them in this Z-up scene:
- **Tiles / map objects** — `rotation.set(Math.PI / 2, Math.PI / 6, 0)`: X-rotation lays the model flat in XY, Y-rotation aligns it to the hex grid.
- **Characters** — `rotation.set(Math.PI / 2, 0, 0)`: X-rotation makes the model stand upright along Z. Yaw (facing direction) is then controlled via `rotation.y`.

`OrbitControls` setup that matches this convention:
```js
camera.up.set(0, 0, 1)
controls.minPolarAngle = 0
controls.maxPolarAngle = Math.PI / 2 - 0.05  // prevent going below the board
```

## Common mistakes

- **Invisible skinned mesh** — used `.clone()` instead of `cloneSkeleton()` on a GLB containing `SkinnedMesh` nodes. Symptom: model loads, all meshes report `visible: true` and `has texture`, but nothing appears.
- **Model not served** — forgot to copy GLB to `priv/static/3d/`. Check browser network tab for 404.
- **Gate count wrong** — added a new `loader.load()` call but forgot to increment the `onModelLoaded` counter threshold. Symptom: board never renders after adding the new model.
- **Animation not found** — `AnimationClip.findByName` returns `null` silently if the name doesn't match. `mixer.clipAction(null)` will throw. Log `gltf.animations.map(a => a.name)` to verify.
- **Character faces wrong direction after move** — yaw is `rotation.y` (not `rotation.z`) because the model is X-rotated 90°. The `+ Math.PI / 2` offset in `atan2` corrects for the model's local forward being +Y in its rotated frame. Adjust this offset if using a model with a different authored facing direction.
- **Camera flips upside-down when tilting** — `OrbitControls` defaults to Y-up. If `camera.up` is not explicitly set to `(0,0,1)`, rotating past vertical will flip the view. Always set `camera.up.set(0, 0, 1)` before constructing `OrbitControls`.
