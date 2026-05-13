import * as THREE from "three"

const ThreeJS = {
  mounted() {
    const w = this.el.clientWidth, h = this.el.clientHeight

    this._scene    = new THREE.Scene()
    this._camera   = new THREE.PerspectiveCamera(75, w / h, 0.1, 1000)
    this._renderer = new THREE.WebGLRenderer({ antialias: true })
    this._renderer.setSize(w, h)
    this._renderer.setPixelRatio(window.devicePixelRatio)
    this.el.appendChild(this._renderer.domElement)

    const geometry = new THREE.BoxGeometry(1, 1, 1)
    const material = new THREE.MeshPhongMaterial({ color: 0x44aa88, shininess: 60 })
    this._cube = new THREE.Mesh(geometry, material)
    this._scene.add(this._cube)

    this._scene.add(new THREE.AmbientLight(0xffffff, 0.5))
    const point = new THREE.PointLight(0xffffff, 1)
    point.position.set(5, 5, 5)
    this._scene.add(point)

    this._camera.position.z = 3
    this._animFrameId = null

    const animate = () => {
      this._animFrameId = requestAnimationFrame(animate)
      this._cube.rotation.x += 0.01
      this._cube.rotation.y += 0.01
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
      if (raycaster.intersectObject(this._cube).length > 0)
        this.pushEvent("randomize_cube", {})
    }
    this._renderer.domElement.addEventListener("click", this._onClick)

    this.handleEvent("randomize_cube", ({ size, x, y }) => {
      this._cube.geometry.dispose()
      this._cube.geometry = new THREE.BoxGeometry(size, size, size)
      this._cube.position.set(x, y, 0)
    })
  },

  destroyed() {
    if (this._animFrameId !== null) cancelAnimationFrame(this._animFrameId)
    window.removeEventListener("resize", this._onResize)
    this._renderer.domElement.removeEventListener("click", this._onClick)
    this._cube.geometry.dispose()
    this._cube.material.dispose()
    this._renderer.dispose()
  }
}

export default ThreeJS
