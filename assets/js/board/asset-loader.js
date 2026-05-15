import * as THREE from "three"
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js"
import { matteify } from "./hex-utils.js"

export class AssetLoader {
  constructor() {
    this._loader = new GLTFLoader()
    this.tiles      = {}
    this.objects    = {}
    this.characters = {}
    this.clips      = {}
  }

  load(assets) {
    const loads = []

    Object.entries(assets.tiles || {}).forEach(([key, url]) => {
      loads.push(this._loadScene(url, scene => {
        matteify(scene)
        this.tiles[key] = scene
      }))
    })

    Object.entries(assets.game_objects || {}).forEach(([key, url]) => {
      loads.push(this._loadScene(url, scene => {
        matteify(scene)
        this.objects[key] = scene
      }))
    })

    Object.entries(assets.characters || {}).forEach(([key, url]) => {
      loads.push(this._loadScene(url, scene => {
        this.characters[key] = scene
      }))
    })

    Object.entries(assets.animations || {}).forEach(([key, { url, clip }]) => {
      loads.push(new Promise(resolve => {
        this._loader.load(url, gltf => {
          this.clips[key] = THREE.AnimationClip.findByName(gltf.animations, clip)
          resolve()
        })
      }))
    })

    return Promise.all(loads)
  }

  _loadScene(url, onLoad) {
    return new Promise(resolve => {
      this._loader.load(url, gltf => {
        onLoad(gltf.scene)
        resolve()
      })
    })
  }
}
