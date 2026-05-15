import * as THREE from "three"
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js"
import { clone as cloneSkeleton } from "three/examples/jsm/utils/SkeletonUtils.js"
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js"

const HEX_SIZE = 1.1
const WALK_DURATION = 0.3

function hexToWorld(q, r) {
  return {
    x: HEX_SIZE * (3 / 2 * q),
    y: -HEX_SIZE * (Math.sqrt(3) / 2 * q + Math.sqrt(3) * r)
  }
}

const HIGHLIGHT_COLORS = {
  movement: new THREE.Color(0xf59e0b),
  player:   new THREE.Color(0x22c55e),
  valid:    new THREE.Color(0xef4444),
  invalid:  new THREE.Color(0x6b7280),
}

const ThreeJSBoard = {
  mounted() {
    const w = this.el.clientWidth, h = this.el.clientHeight

    this._scene    = new THREE.Scene()
    this._camera   = new THREE.PerspectiveCamera(50, w / h, 0.1, 1000)
    this._renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
    this._renderer.setSize(w, h)
    this._renderer.setPixelRatio(window.devicePixelRatio)
    this.el.appendChild(this._renderer.domElement)

    this._scene.add(new THREE.AmbientLight(0xffffff, 0.8))
    const dirLight = new THREE.DirectionalLight(0xffffff, 1.2)
    dirLight.position.set(5, 8, 10)
    this._scene.add(dirLight)

    this._tileMap      = new Map()  // coord key -> { tileNode, objectNode | null }
    this._characterMap = new Map()  // character id -> { node, mixer }

    this._pendingState    = null
    this._currentTurnId   = null
    this._cameraTarget    = null  // Vector3 to pan toward, null when idle

    this._camera.up.set(0, 0, 1)  // Z is up — matches the scene (board in XY plane, tiles rotated flat)

    this._controls = new OrbitControls(this._camera, this._renderer.domElement)
    this._controls.mouseButtons = {
      LEFT:   THREE.MOUSE.ROTATE,
      MIDDLE: THREE.MOUSE.PAN,
      RIGHT:  THREE.MOUSE.PAN,
    }
    this._controls.enableDamping = true
    this._controls.dampingFactor = 0.1
    this._controls.screenSpacePanning = true
    this._controls.minPolarAngle = 0
    this._controls.maxPolarAngle = Math.PI / 2 - 0.05  // stop just before flat

    const CAMERA_PAN_SPEED = 4.0  // higher = snappier pan
    const clock = new THREE.Clock()
    this._animFrameId = null
    const animate = () => {
      this._animFrameId = requestAnimationFrame(animate)
      const delta = clock.getDelta()

      // Smoothly pan camera toward active character (preserves zoom and angle)
      if (this._cameraTarget) {
        const t = Math.min(delta * CAMERA_PAN_SPEED, 1)
        const prevTarget = this._controls.target.clone()
        this._controls.target.lerp(this._cameraTarget, t)
        const shift = this._controls.target.clone().sub(prevTarget)
        this._camera.position.add(shift)
        if (this._controls.target.distanceTo(this._cameraTarget) < 0.01)
          this._cameraTarget = null
      }

      this._controls.update()
      for (const entry of this._characterMap.values()) {
        entry.mixer.update(delta)
        if (entry.moveProgress !== null) {
          entry.moveProgress = Math.min(1, entry.moveProgress + delta / WALK_DURATION)
          entry.node.position.lerpVectors(entry.moveFrom, entry.moveTo, entry.moveProgress)
          if (entry.moveProgress >= 1) entry.moveProgress = null
        }
      }
      this._renderer.render(this._scene, this._camera)
    }
    animate()

    this._onResize = () => {
      const w = this.el.clientWidth, h = this.el.clientHeight
      this._camera.aspect = w / h
      this._camera.updateProjectionMatrix()
      this._renderer.setSize(w, h)
    }
    window.addEventListener("resize", this._onResize)

    // Distinguish a stationary click from a drag — only fire interact on pure clicks.
    const DRAG_THRESHOLD_PX = 4
    let pointerDownPos = null
    const raycaster = new THREE.Raycaster()
    const pointer    = new THREE.Vector2()

    this._onPointerDown = (e) => {
      pointerDownPos = { x: e.clientX, y: e.clientY }
    }
    this._onPointerUp = (e) => {
      if (!pointerDownPos) return
      const dx = e.clientX - pointerDownPos.x
      const dy = e.clientY - pointerDownPos.y
      pointerDownPos = null
      if (Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD_PX) return  // was a drag

      const rect = this._renderer.domElement.getBoundingClientRect()
      pointer.x =  ((e.clientX - rect.left)  / rect.width)  * 2 - 1
      pointer.y = -((e.clientY - rect.top)   / rect.height) * 2 + 1
      raycaster.setFromCamera(pointer, this._camera)

      const allNodes = [
        ...[...this._tileMap.values()].flatMap(({ tileNode, objectNode }) =>
          objectNode ? [tileNode, objectNode] : [tileNode]
        ),
        ...[...this._characterMap.values()].map(e => e.node)
      ]
      const meshes = allNodes.flatMap(n => {
        const acc = []
        n.traverse(o => { if (o.isMesh || o.isSkinnedMesh) acc.push(o) })
        return acc
      })

      const hits = raycaster.intersectObjects(meshes)
      if (hits.length === 0) return

      let node = hits[0].object
      while (node.parent && !node.userData.coord && !node.userData.characterId)
        node = node.parent

      if (node.userData.characterId !== undefined)
        this.pushEvent("interact", { target_character_id: node.userData.characterId })
      else if (node.userData.coord)
        this.pushEvent("interact", { target_position: node.userData.coord })
    }
    this._renderer.domElement.addEventListener("pointerdown", this._onPointerDown)
    this._renderer.domElement.addEventListener("pointerup",   this._onPointerUp)

    // Asset registries — populated by the `init` event
    this._tileTemplates      = {}  // key -> THREE.Group
    this._objectTemplates    = {}  // key -> THREE.Group
    this._characterTemplates = {}  // key -> THREE.Group
    this._animationClips     = {}  // key -> THREE.AnimationClip
    this._assetsReady        = false

    const loader = new GLTFLoader()

    this.handleEvent("init", ({ assets }) => {
      const loads = []

      Object.entries(assets.tiles || {}).forEach(([key, url]) => {
        loads.push(new Promise(resolve => loader.load(url, gltf => {
          this._tileTemplates[key] = gltf.scene
          resolve()
        })))
      })

      Object.entries(assets.game_objects || {}).forEach(([key, url]) => {
        loads.push(new Promise(resolve => loader.load(url, gltf => {
          this._objectTemplates[key] = gltf.scene
          resolve()
        })))
      })

      Object.entries(assets.characters || {}).forEach(([key, url]) => {
        loads.push(new Promise(resolve => loader.load(url, gltf => {
          this._characterTemplates[key] = gltf.scene
          resolve()
        })))
      })

      Object.entries(assets.animations || {}).forEach(([key, { url, clip }]) => {
        loads.push(new Promise(resolve => loader.load(url, gltf => {
          this._animationClips[key] = THREE.AnimationClip.findByName(gltf.animations, clip)
          resolve()
        })))
      })

      Promise.all(loads).then(() => {
        this._assetsReady = true
        if (this._pendingState) {
          this._applyBoardState(this._pendingState)
          this._pendingState = null
        }
      })
    })

    this.handleEvent("board_state", (state) => {
      if (this._assetsReady) this._applyBoardState(state)
      else this._pendingState = state
    })
  },

  _applyBoardState({ tiles, characters, current_turn_id }) {
    this._syncTiles(tiles)
    this._syncCharacters(characters)

    if (this._tileMap.size > 0 && !this._cameraFitted) {
      this._fitCamera()
      this._cameraFitted = true
    }

    // Pan camera when the active character changes
    if (current_turn_id !== undefined && current_turn_id !== this._currentTurnId) {
      this._currentTurnId = current_turn_id
      const entry = this._characterMap.get(current_turn_id)
      if (entry) {
        const p = entry.node.position
        this._cameraTarget = new THREE.Vector3(p.x, p.y, p.z)
      }
    }
  },

  _syncTiles(tiles) {
    const incoming = new Set(tiles.map(t => `${t.q}_${t.r}_${t.s}`))

    for (const [key, { tileNode, objectNode }] of this._tileMap) {
      if (!incoming.has(key)) {
        this._scene.remove(tileNode)
        if (objectNode) this._scene.remove(objectNode)
        this._tileMap.delete(key)
      }
    }

    tiles.forEach(({ q, r, s, has_object, highlight }) => {
      const key = `${q}_${r}_${s}`
      const { x, y } = hexToWorld(q, r)
      let entry = this._tileMap.get(key)

      if (!entry) {
        const tileTemplate = this._tileTemplates.default
        const tileNode = tileTemplate.clone()
        tileNode.position.set(x, y, 0)
        tileNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
        tileNode.userData.coord = key
        this._scene.add(tileNode)

        let objectNode = null
        if (has_object && this._objectTemplates.default) {
          objectNode = this._objectTemplates.default.clone()
          objectNode.scale.set(3, 3, 3)
          objectNode.position.set(x, y, 0.9)
          objectNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
          this._scene.add(objectNode)
        }

        entry = { tileNode, objectNode }
        this._tileMap.set(key, entry)
      }

      const color = highlight ? HIGHLIGHT_COLORS[highlight] : null
      entry.tileNode.traverse(o => {
        if (!o.isMesh) return
        if (!o.userData.baseMaterial) o.userData.baseMaterial = o.material.clone()
        if (color) {
          o.material = o.userData.baseMaterial.clone()
          o.material.emissive = color
          o.material.emissiveIntensity = 0.5
        } else {
          o.material = o.userData.baseMaterial
        }
      })
    })
  },

  _syncCharacters(characters) {
    const incoming = new Set(characters.map(c => String(c.id)))

    for (const [id, { node, mixer, walkTimer }] of this._characterMap) {
      if (!incoming.has(String(id))) {
        if (walkTimer) clearTimeout(walkTimer)
        mixer.stopAllAction()
        this._scene.remove(node)
        this._characterMap.delete(id)
      }
    }

    characters.forEach(({ id, q, r }) => {
      const { x, y } = hexToWorld(q, r)
      let entry = this._characterMap.get(id)

      if (!entry) {
        const node = cloneSkeleton(this._characterTemplates.default)
        node.userData.characterId = id
        node.rotation.set(Math.PI / 2, 0, 0)
        node.scale.setScalar(0.6)
        this._scene.add(node)

        const mixer = new THREE.AnimationMixer(node)
        const idleAction = mixer.clipAction(this._animationClips.idle)
        const walkAction = mixer.clipAction(this._animationClips.walk)
        walkAction.enabled = true
        idleAction.play()

        entry = { node, mixer, idleAction, walkAction, walkTimer: null, moveFrom: new THREE.Vector3(), moveTo: new THREE.Vector3(), moveProgress: null }
        this._characterMap.set(id, entry)
        entry.node.position.set(x, y, 1)
        return
      }

      const cur = entry.node.position
      const moved = Math.abs(cur.x - x) > 0.001 || Math.abs(cur.y - y) > 0.001
      if (moved) {
        // Face direction of movement — rotation.y is yaw when the model is X-rotated 90°
        entry.node.rotation.y = Math.atan2(y - cur.y, x - cur.x) + Math.PI / 2

        // Start lerp from current position (which may itself be mid-tween)
        entry.moveFrom.copy(cur)
        entry.moveTo.set(x, y, 1)
        entry.moveProgress = 0

        // Crossfade to walk, then back to idle after walk duration
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
  },

  _fitCamera() {
    const allNodes = [
      ...[...this._tileMap.values()].map(e => e.tileNode),
      ...[...this._characterMap.values()].map(e => e.node)
    ]
    if (allNodes.length === 0) return
    const box = new THREE.Box3()
    allNodes.forEach(n => box.expandByObject(n))
    const center = box.getCenter(new THREE.Vector3())
    const size   = box.getSize(new THREE.Vector3())
    const maxDim = Math.max(size.x, size.y)
    const fov    = this._camera.fov * (Math.PI / 180)
    const dist   = (maxDim / 2) / Math.tan(fov / 2) + 2
    this._camera.position.set(center.x, center.y - dist * 0.6, dist * 0.8)
    this._controls.target.copy(center)
    this._controls.update()
  },

  destroyed() {
    if (this._animFrameId !== null) cancelAnimationFrame(this._animFrameId)
    window.removeEventListener("resize", this._onResize)
    this._renderer.domElement.removeEventListener("pointerdown", this._onPointerDown)
    this._renderer.domElement.removeEventListener("pointerup",   this._onPointerUp)
    this._controls.dispose()
    for (const { tileNode, objectNode } of this._tileMap.values()) {
      this._scene.remove(tileNode)
      if (objectNode) this._scene.remove(objectNode)
    }
    for (const { node, mixer, walkTimer } of this._characterMap.values()) {
      if (walkTimer) clearTimeout(walkTimer)
      mixer.stopAllAction()
      this._scene.remove(node)
    }
    this._renderer.dispose()
  }
}

export default ThreeJSBoard
