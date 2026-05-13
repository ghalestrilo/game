import * as THREE from "three"

const HEX_SIZE = 1.1  // distance from center to corner, controls spacing

function hexToWorld(q, r) {
  // Flat-top axial to world coordinates
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
    this.el.appendChild(this._renderer.domElement)

    this._scene.add(new THREE.AmbientLight(0xffffff, 0.5))
    const point = new THREE.PointLight(0xffffff, 1)
    point.position.set(5, 5, 10)
    this._scene.add(point)

    // Start with a single placeholder cube until map data arrives
    this._tileMaterial = new THREE.MeshPhongMaterial({ color: 0x44aa88, shininess: 60 })
    this._tiles = []
    this._addCube(0, 0)

    this._camera.position.z = 20
    this._animFrameId = null

    const animate = () => {
      this._animFrameId = requestAnimationFrame(animate)
      this._tiles.forEach(mesh => {
        mesh.rotation.x += 0.01
        mesh.rotation.y += 0.01
      })
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
      if (raycaster.intersectObjects(this._tiles).length > 0)
        this.pushEvent("randomize_cube", {})
    }
    this._renderer.domElement.addEventListener("click", this._onClick)

    this.handleEvent("load_map", ({ tiles }) => {
      this._clearTiles()
      tiles.forEach(({ q, r }) => this._addCube(q, r))
      this._fitCamera()
    })

    this.handleEvent("randomize_cube", ({ size, x, y }) => {
      this._tiles.forEach(mesh => {
        mesh.geometry.dispose()
        mesh.geometry = new THREE.BoxGeometry(size, size, size)
      })
    })
  },

  _addCube(q, r) {
    const { x, y } = hexToWorld(q, r)
    const geometry = new THREE.BoxGeometry(0.85, 0.85, 0.85)
    const mesh = new THREE.Mesh(geometry, this._tileMaterial)
    mesh.position.set(x, y, 0)
    this._scene.add(mesh)
    this._tiles.push(mesh)
  },

  _clearTiles() {
    this._tiles.forEach(mesh => {
      this._scene.remove(mesh)
      mesh.geometry.dispose()
    })
    this._tiles = []
  },

  // Move camera to frame all tiles
  _fitCamera() {
    if (this._tiles.length === 0) return
    const box = new THREE.Box3()
    this._tiles.forEach(m => box.expandByObject(m))
    const center = box.getCenter(new THREE.Vector3())
    const size   = box.getSize(new THREE.Vector3())
    const maxDim = Math.max(size.x, size.y)
    const fov    = this._camera.fov * (Math.PI / 180)
    this._camera.position.set(center.x, center.y, (maxDim / 2) / Math.tan(fov / 2) + 2)
    this._camera.lookAt(center)
  },

  destroyed() {
    if (this._animFrameId !== null) cancelAnimationFrame(this._animFrameId)
    window.removeEventListener("resize", this._onResize)
    this._renderer.domElement.removeEventListener("click", this._onClick)
    this._clearTiles()
    this._tileMaterial.dispose()
    this._renderer.dispose()
  }
}

export default ThreeJS
