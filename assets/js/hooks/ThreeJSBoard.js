import * as THREE from "three"
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js"

const HEX_SIZE = 1.1

// Flat-top axial to world XY
function hexToWorld(q, r) {
  return {
    x: HEX_SIZE * (3 / 2 * q),
    y: HEX_SIZE * (Math.sqrt(3) / 2 * q + Math.sqrt(3) * r)
  }
}

const HIGHLIGHT_COLORS = {
  movement: new THREE.Color(0xf59e0b),  // amber
  player:   new THREE.Color(0x22c55e),  // green
  valid:    new THREE.Color(0xef4444),  // red
  invalid:  new THREE.Color(0x6b7280),  // gray
}

const ThreeJSBoard = {
  mounted() {
    const w = this.el.clientWidth, h = this.el.clientHeight

    this._scene    = new THREE.Scene()
    this._camera   = new THREE.PerspectiveCamera(50, w / h, 0.1, 1000)
    this._renderer = new THREE.WebGLRenderer({ antialias: true })
    this._renderer.setSize(w, h)
    this._renderer.setPixelRatio(window.devicePixelRatio)
    this.el.appendChild(this._renderer.domElement)

    this._scene.add(new THREE.AmbientLight(0xffffff, 0.8))
    const dirLight = new THREE.DirectionalLight(0xffffff, 1.2)
    dirLight.position.set(5, 8, 10)
    this._scene.add(dirLight)

    // tile coord key -> { tileNode, objectNode | null }
    this._tileMap      = new Map()
    // character id -> node
    this._characterMap = new Map()

    this._tileTemplate  = null
    this._objectTemplate = null
    this._mageTemplate  = null
    this._pendingState  = null

    this._animFrameId = null
    const animate = () => {
      this._animFrameId = requestAnimationFrame(animate)
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

    // Raycaster — clicks on tiles push interact with coord, clicks on characters push interact with id
    const raycaster = new THREE.Raycaster()
    const pointer   = new THREE.Vector2()
    this._onClick = (e) => {
      const rect = this._renderer.domElement.getBoundingClientRect()
      pointer.x =  ((e.clientX - rect.left)  / rect.width)  * 2 - 1
      pointer.y = -((e.clientY - rect.top)   / rect.height) * 2 + 1
      raycaster.setFromCamera(pointer, this._camera)

      const allNodes = [
        ...[...this._tileMap.values()].flatMap(({ tileNode, objectNode }) =>
          objectNode ? [tileNode, objectNode] : [tileNode]
        ),
        ...[...this._characterMap.values()]
      ]
      const meshes = allNodes.flatMap(n => {
        const acc = []
        n.traverse(o => { if (o.isMesh) acc.push(o) })
        return acc
      })

      const hits = raycaster.intersectObjects(meshes)
      if (hits.length === 0) return

      const hitMesh = hits[0].object
      // Walk up to find the root node we track
      let node = hitMesh
      while (node.parent && !node.userData.coord && !node.userData.characterId)
        node = node.parent

      if (node.userData.characterId !== undefined)
        this.pushEvent("interact", { target_character_id: node.userData.characterId })
      else if (node.userData.coord)
        this.pushEvent("interact", { target_position: node.userData.coord })
    }
    this._renderer.domElement.addEventListener("click", this._onClick)

    // Load all models before accepting board_state
    let loadedCount = 0
    const onModelLoaded = () => {
      if (++loadedCount < 3) return
      if (this._pendingState) {
        this._applyBoardState(this._pendingState)
        this._pendingState = null
      }
    }

    const loader = new GLTFLoader()
    loader.load("/3d/tiles/hex_forest_detail.gltf.glb", gltf => { this._tileTemplate   = gltf.scene; onModelLoaded() })
    loader.load("/3d/tiles/detail_treeA.gltf.glb",      gltf => { this._objectTemplate = gltf.scene; onModelLoaded() })
    loader.load("/3d/characters/Mage.glb",               gltf => { this._mageTemplate   = gltf.scene; onModelLoaded() })

    const allLoaded = () => this._tileTemplate && this._objectTemplate && this._mageTemplate

    this.handleEvent("board_state", (state) => {
      if (allLoaded()) this._applyBoardState(state)
      else this._pendingState = state
    })
  },

  _applyBoardState({ tiles, characters, blast_map }) {
    this._syncTiles(tiles)
    this._syncCharacters(characters)
    if (this._tileMap.size > 0 && !this._cameraFitted) {
      this._fitCamera()
      this._cameraFitted = true
    }
  },

  _syncTiles(tiles) {
    const incoming = new Set(tiles.map(t => `${t.q}_${t.r}_${t.s}`))

    // Remove tiles no longer in the map
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
        // New tile — clone and place
        const tileNode = this._tileTemplate.clone()
        tileNode.position.set(x, y, 0)
        tileNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
        tileNode.userData.coord = key
        this._scene.add(tileNode)

        let objectNode = null
        if (has_object) {
          objectNode = this._objectTemplate.clone()
          objectNode.scale.set(3, 3, 3)
          objectNode.position.set(x, y, 0.9)
          objectNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
          this._scene.add(objectNode)
        }

        entry = { tileNode, objectNode }
        this._tileMap.set(key, entry)
      }

      // Apply highlight tint
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

    // Remove characters no longer present
    for (const [id, node] of this._characterMap) {
      if (!incoming.has(String(id))) {
        this._scene.remove(node)
        this._characterMap.delete(id)
      }
    }

    characters.forEach(({ id, q, r }) => {
      const { x, y } = hexToWorld(q, r)
      let node = this._characterMap.get(id)

      if (!node) {
        node = this._mageTemplate.clone()
        node.userData.characterId = id
        this._scene.add(node)
        this._characterMap.set(id, node)
      }

      node.position.set(x, y, 0)
    })
  },

  _fitCamera() {
    const allNodes = [
      ...[...this._tileMap.values()].map(e => e.tileNode),
      ...[...this._characterMap.values()]
    ]
    if (allNodes.length === 0) return
    const box = new THREE.Box3()
    allNodes.forEach(n => box.expandByObject(n))
    const center = box.getCenter(new THREE.Vector3())
    const size   = box.getSize(new THREE.Vector3())
    const maxDim = Math.max(size.x, size.y)
    const fov    = this._camera.fov * (Math.PI / 180)
    this._camera.position.set(center.x, -maxDim, (maxDim / 4) / Math.tan(fov / 2) + 2)
    this._camera.lookAt(center)
  },

  destroyed() {
    if (this._animFrameId !== null) cancelAnimationFrame(this._animFrameId)
    window.removeEventListener("resize", this._onResize)
    this._renderer.domElement.removeEventListener("click", this._onClick)
    for (const { tileNode, objectNode } of this._tileMap.values()) {
      this._scene.remove(tileNode)
      if (objectNode) this._scene.remove(objectNode)
    }
    for (const node of this._characterMap.values()) this._scene.remove(node)
    this._renderer.dispose()
  }
}

export default ThreeJSBoard
