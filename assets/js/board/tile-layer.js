import { hexToWorld, meshesOf, HIGHLIGHT_COLORS } from "./hex-utils.js"

export class TileLayer {
  constructor(scene, assetLoader) {
    this._scene  = scene
    this._assets = assetLoader
    this._map    = new Map()  // coord key -> { tileNode, objectNode | null, serverHighlight }
  }

  sync(tiles) {
    const incoming = new Set(tiles.map(t => `${t.q}_${t.r}_${t.s}`))

    for (const [key, { tileNode, objectNode }] of this._map) {
      if (!incoming.has(key)) {
        this._scene.remove(tileNode)
        if (objectNode) this._scene.remove(objectNode)
        this._map.delete(key)
      }
    }

    tiles.forEach(({ q, r, s, has_object, highlight }) => {
      const key = `${q}_${r}_${s}`
      const { x, y } = hexToWorld(q, r)
      let entry = this._map.get(key)

      if (!entry) {
        const tileNode = this._assets.tiles.default.clone()
        tileNode.position.set(x, y, 0)
        tileNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
        tileNode.userData.coord = key
        this._scene.add(tileNode)

        let objectNode = null
        if (has_object && this._assets.objects.default) {
          objectNode = this._assets.objects.default.clone()
          objectNode.scale.set(3, 3, 3)
          objectNode.position.set(x, y, 0.9)
          objectNode.rotation.set(Math.PI / 2, Math.PI / 6, 0)
          this._scene.add(objectNode)
        }

        entry = { tileNode, objectNode, serverHighlight: null }
        this._map.set(key, entry)
      }

      entry.serverHighlight = highlight || null
    })
  }

  applyHighlights(hoveredCoord, blastMap) {
    const blastCoords = hoveredCoord
      ? new Set(blastMap[hoveredCoord] || [])
      : new Set()

    for (const [key, { tileNode, serverHighlight }] of this._map) {
      if (key === hoveredCoord) {
        this._tint(tileNode, HIGHLIGHT_COLORS.valid, 0.9)
      } else if (blastCoords.has(key)) {
        this._tint(tileNode, HIGHLIGHT_COLORS.blast, 0.7)
      } else {
        const color = serverHighlight ? HIGHLIGHT_COLORS[serverHighlight] : null
        this._tint(tileNode, color, 0.5)
      }
    }
  }

  tileMeshes() {
    return [...this._map.values()].flatMap(({ tileNode }) => meshesOf(tileNode))
  }

  positionOf(coord) {
    const entry = this._map.get(coord)
    return entry ? entry.tileNode.position.clone() : null
  }

  allNodes() {
    return [...this._map.values()].map(e => e.tileNode)
  }

  destroy() {
    for (const { tileNode, objectNode } of this._map.values()) {
      this._scene.remove(tileNode)
      if (objectNode) this._scene.remove(objectNode)
    }
    this._map.clear()
  }

  _tint(node, color, intensity) {
    node.traverse(o => {
      if (!o.isMesh) return
      if (!o.userData.baseMaterial) o.userData.baseMaterial = o.material.clone()
      if (color) {
        o.material = o.userData.baseMaterial.clone()
        o.material.emissive = color
        o.material.emissiveIntensity = intensity
      } else {
        o.material = o.userData.baseMaterial
      }
    })
  }
}
