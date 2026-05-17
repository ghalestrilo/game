import * as THREE from "three"
import { clone as cloneSkeleton } from "three/examples/jsm/utils/SkeletonUtils.js"
import { hexToWorld } from "./hex-utils.js"

const WALK_DURATION = 0.3

export class CharacterLayer {
  constructor(scene, assetLoader) {
    this._scene  = scene
    this._assets = assetLoader
    this._map    = new Map()  // id -> { node, mixer, idleAction, walkAction, walkTimer, moveFrom, moveTo, moveProgress }
  }

  sync(characters) {
    const incoming = new Set(characters.map(c => String(c.id)))

    for (const [id, entry] of this._map) {
      if (!incoming.has(String(id))) {
        if (entry.walkTimer) clearTimeout(entry.walkTimer)
        entry.mixer.stopAllAction()
        this._scene.remove(entry.node)
        this._map.delete(id)
      }
    }

    characters.forEach(({ id, q, r, model_url }) => {
      const { x, y } = hexToWorld(q, r)
      let entry = this._map.get(id)

      if (!entry) {
        this._map.set(id, { pending: true })
        this._assets.loadCharacter(model_url).then(template => {
          if (!this._map.has(id)) return  // removed while loading
          const node = cloneSkeleton(template)
          node.userData.characterId = id
          node.rotation.set(Math.PI / 2, 0, 0)
          node.scale.setScalar(0.6)
          node.position.set(x, y, 1)
          this._scene.add(node)

          const mixer = new THREE.AnimationMixer(node)
          const idleAction = mixer.clipAction(this._assets.clips.idle)
          const walkAction = mixer.clipAction(this._assets.clips.walk)
          walkAction.enabled = true
          idleAction.play()

          this._map.set(id, {
            node, mixer, idleAction, walkAction,
            walkTimer: null,
            moveFrom: new THREE.Vector3(),
            moveTo: new THREE.Vector3(),
            moveProgress: null
          })
          // Face toward center of mass now that this character is loaded
          const center = this.centerOfMass()
          if (this.allNodes().length > 0) this.faceToward(center)
        })
        return
      }

      if (entry.pending) return

      const cur = entry.node.position
      const moved = Math.abs(cur.x - x) > 0.001 || Math.abs(cur.y - y) > 0.001
      if (moved) {
        entry.node.rotation.y = Math.atan2(y - cur.y, x - cur.x) + Math.PI / 2

        entry.moveFrom.copy(cur)
        entry.moveTo.set(x, y, 1)
        entry.moveProgress = 0

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
  }

  update(delta) {
    for (const entry of this._map.values()) {
      if (entry.pending) continue
      entry.mixer.update(delta)
      if (entry.moveProgress !== null) {
        entry.moveProgress = Math.min(1, entry.moveProgress + delta / WALK_DURATION)
        entry.node.position.lerpVectors(entry.moveFrom, entry.moveTo, entry.moveProgress)
        if (entry.moveProgress >= 1) entry.moveProgress = null
      }
    }
  }

  centerOfMass() {
    const nodes = this.allNodes()
    if (nodes.length === 0) return new THREE.Vector3()
    return nodes
      .reduce((acc, n) => acc.add(n.position), new THREE.Vector3())
      .divideScalar(nodes.length)
  }

  faceToward(center) {
    for (const { pending, node, moveProgress } of this._map.values()) {
      if (pending || moveProgress !== null) continue
      const dx = center.x - node.position.x
      const dy = center.y - node.position.y
      if (Math.abs(dx) > 0.001 || Math.abs(dy) > 0.001)
        node.rotation.y = Math.atan2(dy, dx) + Math.PI / 2
    }
  }

  get(id) {
    const entry = this._map.get(id)
    return entry?.pending ? null : entry
  }

  allNodes() {
    return [...this._map.values()].filter(e => !e.pending).map(e => e.node)
  }

  destroy() {
    for (const entry of this._map.values()) {
      if (entry.pending) continue
      if (entry.walkTimer) clearTimeout(entry.walkTimer)
      entry.mixer.stopAllAction()
      this._scene.remove(entry.node)
    }
    this._map.clear()
  }
}
