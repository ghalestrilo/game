import * as THREE from "three"
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js"

const HEX_SIZE = 1.1

function hexToWorld(q, r) {
  return {
    x: HEX_SIZE * (3 / 2 * q),
    y: HEX_SIZE * (Math.sqrt(3) / 2 * q + Math.sqrt(3) * r)
  }
}

const ThreeJS = {
  mounted() {
    const w = this.el.clientWidth, h = this.el.clientHeight

    this._scene    = new THREE.Scene()
    this._camera   = new THREE.PerspectiveCamera(50, w / h, 0.1, 1000)
    this._renderer = new THREE.WebGLRenderer({ antialias: true })
    this._renderer.setSize(w, h)
    this._renderer.setPixelRatio(window.devicePixelRatio)
    this._renderer.shadowMap.enabled = true
    this.el.appendChild(this._renderer.domElement)

    this._scene.add(new THREE.AmbientLight(0xffffff, 0.8))
    const dirLight = new THREE.DirectionalLight(0xffffff, 1.2)
    dirLight.position.set(5, 8, 10)
    this._scene.add(dirLight)

    this._tiles    = []
    this._tileTemplate = null  // cloned per tile once loaded
    this._pendingTiles = null  // tile coords waiting for model to load

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

    const raycaster = new THREE.Raycaster()
    const pointer   = new THREE.Vector2()
    this._onClick = (e) => {
      const rect = this._renderer.domElement.getBoundingClientRect()
      pointer.x =  ((e.clientX - rect.left)  / rect.width)  * 2 - 1
      pointer.y = -((e.clientY - rect.top)   / rect.height) * 2 + 1
      raycaster.setFromCamera(pointer, this._camera)
      const meshes = this._tiles.flatMap(t => {
        const hits = []
        t.traverse(o => { if (o.isMesh) hits.push(o) })
        return hits
      })
      if (raycaster.intersectObjects(meshes).length > 0)
        this.pushEvent("randomize_cube", {})
    }
    this._renderer.domElement.addEventListener("click", this._onClick)

    const loader = new GLTFLoader()
    loader.load("/3d/tiles/hex_forest_detail.gltf.glb", (gltf) => {
      this._tileTemplate = gltf.scene
      if (this._pendingTiles) {
        this._spawnTiles(this._pendingTiles)
        this._pendingTiles = null
      }
    })

    this.handleEvent("load_map", ({ tiles }) => {
      if (this._tileTemplate) {
        this._spawnTiles(tiles)
      } else {
        this._pendingTiles = tiles
      }
    })

    this.handleEvent("randomize_cube", ({ size, x, y }) => {
      this._tiles.forEach((tile, i) => {
        const angle = (i / this._tiles.length) * Math.PI * 2
        tile.position.set(
          tile.position.x + Math.cos(angle) * x,
          tile.position.y + Math.sin(angle) * y,
          0
        )
        tile.scale.setScalar(size)
      })
    })
  },

  _spawnTiles(tiles) {
    this._clearTiles()
    tiles.forEach(({ q, r }) => {
      const { x, y } = hexToWorld(q, r)
      const instance = this._tileTemplate.clone()
      instance.position.set(x, y, 0)
      instance.rotation.set(Math.PI / 2, Math.PI / 6, 0)
      this._scene.add(instance)
      this._tiles.push(instance)
    })
    this._fitCamera()
  },

  _clearTiles() {
    this._tiles.forEach(t => this._scene.remove(t))
    this._tiles = []
  },

  _fitCamera() {
    if (this._tiles.length === 0) return
    const box = new THREE.Box3()
    this._tiles.forEach(t => box.expandByObject(t))
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
    this._clearTiles()
    this._renderer.dispose()
  }
}

export default ThreeJS
