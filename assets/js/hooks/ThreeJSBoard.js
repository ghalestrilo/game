import * as THREE from "three"
import { AssetLoader }    from "../board/asset-loader.js"
import { TileLayer }      from "../board/tile-layer.js"
import { CharacterLayer } from "../board/character-layer.js"
import { BoardCamera }    from "../board/board-camera.js"
import { meshesOf }       from "../board/hex-utils.js"

const ThreeJSBoard = {
  mounted() {
    const w = this.el.clientWidth, h = this.el.clientHeight

    // --- Scene bootstrap ---
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

    // --- Modules ---
    this._assets    = new AssetLoader()
    this._tiles     = new TileLayer(this._scene, this._assets)
    this._characters = new CharacterLayer(this._scene, this._assets)
    this._boardCamera = new BoardCamera(this._camera, this._renderer.domElement)

    // --- Render loop ---
    const clock = new THREE.Clock()
    this._animFrameId = null
    const animate = () => {
      this._animFrameId = requestAnimationFrame(animate)
      const delta = clock.getDelta()
      this._boardCamera.update(delta)
      this._characters.update(delta)
      this._renderer.render(this._scene, this._camera)
    }
    animate()

    // --- Resize ---
    this._onResize = () => {
      const w = this.el.clientWidth, h = this.el.clientHeight
      this._boardCamera.onResize(w, h)
      this._renderer.setSize(w, h)
    }
    window.addEventListener("resize", this._onResize)

    // --- Click: interact ---
    const DRAG_THRESHOLD_PX = 4
    let pointerDownPos = null
    const clickRaycaster = new THREE.Raycaster()
    const clickPointer   = new THREE.Vector2()

    this._onPointerDown = (e) => { pointerDownPos = { x: e.clientX, y: e.clientY } }
    this._onPointerUp   = (e) => {
      if (!pointerDownPos) return
      const dx = e.clientX - pointerDownPos.x
      const dy = e.clientY - pointerDownPos.y
      pointerDownPos = null
      if (Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD_PX) return

      const rect = this._renderer.domElement.getBoundingClientRect()
      clickPointer.x =  ((e.clientX - rect.left)  / rect.width)  * 2 - 1
      clickPointer.y = -((e.clientY - rect.top)   / rect.height) * 2 + 1
      clickRaycaster.setFromCamera(clickPointer, this._camera)

      const meshes = [
        ...this._tiles.allNodes(),
        ...this._characters.allNodes()
      ].flatMap(n => meshesOf(n, { skinned: true }))

      const hits = clickRaycaster.intersectObjects(meshes)
      if (hits.length === 0) return

      let node = hits[0].object
      while (node.parent && node.userData.coord === undefined && node.userData.characterId === undefined)
        node = node.parent

      if (node.userData.characterId !== undefined)
        this.pushEvent("interact", { target_character_id: node.userData.characterId })
      else if (node.userData.coord)
        this.pushEvent("interact", { target_position: node.userData.coord })
    }

    // --- Hover: blast highlight ---
    const hoverRaycaster = new THREE.Raycaster()
    const hoverPointer   = new THREE.Vector2()
    this._hoveredCoord = null
    this._blastMap     = {}

    this._onPointerMove  = (e) => {
      const rect = this._renderer.domElement.getBoundingClientRect()
      hoverPointer.x =  ((e.clientX - rect.left)  / rect.width)  * 2 - 1
      hoverPointer.y = -((e.clientY - rect.top)   / rect.height) * 2 + 1
      hoverRaycaster.setFromCamera(hoverPointer, this._camera)

      const hits = hoverRaycaster.intersectObjects(this._tiles.tileMeshes())
      let coord = null
      if (hits.length > 0) {
        let node = hits[0].object
        while (node.parent && !node.userData.coord) node = node.parent
        coord = node.userData.coord || null
      }
      if (coord !== this._hoveredCoord) {
        this._hoveredCoord = coord
        this._tiles.applyHighlights(this._hoveredCoord, this._blastMap)
      }
    }
    this._onPointerLeave = () => {
      this._hoveredCoord = null
      this._tiles.applyHighlights(null, this._blastMap)
    }

    this._renderer.domElement.addEventListener("pointerdown",  this._onPointerDown)
    this._renderer.domElement.addEventListener("pointerup",    this._onPointerUp)
    this._renderer.domElement.addEventListener("pointermove",  this._onPointerMove)
    this._renderer.domElement.addEventListener("pointerleave", this._onPointerLeave)

    // --- LiveView events ---
    this._cameraFitted  = false
    this._currentTurnId = null

    this.handleEvent("init", ({ assets }) => {
      this._assets.load(assets).then(() => {
        if (this._pendingState) {
          this._applyBoardState(this._pendingState)
          this._pendingState = null
        }
      })
    })

    this.handleEvent("board_state", (state) => {
      if (this._assets.tiles.default) this._applyBoardState(state)
      else this._pendingState = state
    })

    this.handleEvent("highlight-tile", ({ coord }) => {
      this._hoveredCoord = coord
      this._tiles.applyHighlights(this._hoveredCoord, this._blastMap)
      const pos = this._tiles.positionOf(coord)
      if (pos) this._boardCamera.panTo(pos)
    })
  },

  _applyBoardState({ tiles, characters, current_turn_id, blast_map }) {
    this._blastMap = blast_map || {}
    this._tiles.sync(tiles)
    this._tiles.applyHighlights(this._hoveredCoord, this._blastMap)
    this._characters.sync(characters)

    const center = this._characters.centerOfMass()
    if (this._characters.allNodes().length > 0) this._characters.faceToward(center)

    if (!this._cameraFitted && this._tiles.allNodes().length > 0) {
      this._boardCamera.fitToNodes([
        ...this._tiles.allNodes(),
        ...this._characters.allNodes()
      ])
      this._cameraFitted = true
    }

    if (current_turn_id !== undefined && current_turn_id !== this._currentTurnId) {
      this._currentTurnId = current_turn_id
      const entry = this._characters.get(current_turn_id)
      if (entry && !entry.pending)
        this._boardCamera.panTo(center.clone().lerp(entry.node.position, 0.5))
    }
  },

  destroyed() {
    if (this._animFrameId !== null) cancelAnimationFrame(this._animFrameId)
    window.removeEventListener("resize", this._onResize)
    this._renderer.domElement.removeEventListener("pointerdown",  this._onPointerDown)
    this._renderer.domElement.removeEventListener("pointerup",    this._onPointerUp)
    this._renderer.domElement.removeEventListener("pointermove",  this._onPointerMove)
    this._renderer.domElement.removeEventListener("pointerleave", this._onPointerLeave)
    this._tiles.destroy()
    this._characters.destroy()
    this._boardCamera.destroy()
    this._renderer.dispose()
  }
}

export default ThreeJSBoard
