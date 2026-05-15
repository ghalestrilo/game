import * as THREE from "three"

export const HEX_SIZE = 1.1

export function hexToWorld(q, r) {
  return {
    x:  HEX_SIZE * (3 / 2 * q),
    y: -HEX_SIZE * (Math.sqrt(3) / 2 * q + Math.sqrt(3) * r)
  }
}

export function matteify(scene) {
  scene.traverse(o => {
    if (!o.isMesh) return
    o.material.roughness = 1.0
    o.material.metalness = 0.0
  })
}

export function meshesOf(node, { skinned = false } = {}) {
  const acc = []
  node.traverse(o => { if (o.isMesh || (skinned && o.isSkinnedMesh)) acc.push(o) })
  return acc
}

export function rootNodeOf(mesh, userData) {
  let node = mesh
  while (node.parent && !userData.some(k => node.userData[k] !== undefined))
    node = node.parent
  return node
}

export const HIGHLIGHT_COLORS = {
  movement: new THREE.Color(0xf59e0b),
  player:   new THREE.Color(0x22c55e),
  valid:    new THREE.Color(0xef4444),
  invalid:  new THREE.Color(0x6b7280),
  blast:    new THREE.Color(0x991b1b),
}
