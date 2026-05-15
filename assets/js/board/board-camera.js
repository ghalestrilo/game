import * as THREE from "three"
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js"

const PAN_SPEED = 4.0

export class BoardCamera {
  constructor(camera, domElement) {
    this._camera = camera
    this._target = null  // Vector3 to pan toward, null when idle

    camera.up.set(0, 0, 1)

    this._controls = new OrbitControls(camera, domElement)
    this._controls.mouseButtons = {
      LEFT:   THREE.MOUSE.ROTATE,
      MIDDLE: THREE.MOUSE.PAN,
      RIGHT:  THREE.MOUSE.PAN,
    }
    this._controls.enableDamping    = true
    this._controls.dampingFactor    = 0.1
    this._controls.screenSpacePanning = true
    this._controls.minPolarAngle    = 0
    this._controls.maxPolarAngle    = Math.PI / 2 - 0.05
  }

  fitToNodes(nodes) {
    if (nodes.length === 0) return
    const box = new THREE.Box3()
    nodes.forEach(n => box.expandByObject(n))
    const center = box.getCenter(new THREE.Vector3())
    const size   = box.getSize(new THREE.Vector3())
    const maxDim = Math.max(size.x, size.y)
    const fov    = this._camera.fov * (Math.PI / 180)
    const dist   = (maxDim / 2) / Math.tan(fov / 2) + 2
    this._camera.position.set(center.x, center.y - dist * 0.6, dist * 0.8)
    this._controls.target.copy(center)
    this._controls.update()
  }

  panTo(position) {
    this._target = position.clone()
  }

  update(delta) {
    if (this._target) {
      const t = Math.min(delta * PAN_SPEED, 1)
      const prevTarget = this._controls.target.clone()
      this._controls.target.lerp(this._target, t)
      const shift = this._controls.target.clone().sub(prevTarget)
      this._camera.position.add(shift)
      if (this._controls.target.distanceTo(this._target) < 0.01)
        this._target = null
    }
    this._controls.update()
  }

  onResize(w, h) {
    this._camera.aspect = w / h
    this._camera.updateProjectionMatrix()
  }

  destroy() {
    this._controls.dispose()
  }
}
