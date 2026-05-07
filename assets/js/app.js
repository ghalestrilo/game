// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import {Hooks as BackpexHooks} from "backpex"

// Individual class tokens the server controls via data-tile-classes.
// Keep in sync with @overlay_classes, @movement_class, @player_pos_class in combat_live.ex.
const SERVER_CLASSES = [
  "ring-2", "ring-inset", "ring-error/70", "bg-error/5",
  "opacity-40",
  "bg-warning/10",
  "!bg-success/30",
  "blast-preview"
]

const BoardTileClasses = {
  mounted()  { this._applyAll(); this._bindHover() },
  updated()  { this._applyAll() },

  _tiles() {
    const map = {}
    this.el.querySelectorAll("[data-coord]").forEach(el => { map[el.dataset.coord] = el })
    return map
  },

  _applyAll() {
    const classes = JSON.parse(this.el.dataset.tileClasses || "{}")
    const tiles = this._tiles()
    Object.values(tiles).forEach(el => el.classList.remove(...SERVER_CLASSES))
    Object.entries(classes).forEach(([coord, cls]) => tiles[coord]?.classList.add(...cls))
  },

  _bindHover() {
    this.el.addEventListener("mouseover", e => {
      const tile = e.target.closest("[data-coord]")
      if (!tile) return
      const blastMap = JSON.parse(this.el.dataset.blastMap || "{}")
      const tiles = this._tiles()
      this.el.querySelectorAll(".blast-preview").forEach(el => el.classList.remove("blast-preview"))
      ;(blastMap[tile.dataset.coord] || []).forEach(c => tiles[c]?.classList.add("blast-preview"))
    })

    this.el.addEventListener("mouseleave", () => {
      this.el.querySelectorAll(".blast-preview").forEach(el => el.classList.remove("blast-preview"))
    })
  }
}

const CharacterEffects = {
  mounted() {
    window.addEventListener("phx:hit", (e) => {
      if (e.detail.id !== this.el.dataset.characterId) return
      const color = e.detail.color || "yellow"
      const colorClass = `character-hit-${color}`
      this.el.classList.remove("character-hit", "character-hit-red", "character-hit-green", "character-hit-blue", "character-hit-yellow")
      void this.el.offsetWidth // reflow to restart animation
      this.el.classList.add("character-hit", colorClass)
      this.el.addEventListener("animationend", () => {
        this.el.classList.remove("character-hit", colorClass)
      }, {once: true})
    })

    window.addEventListener("phx:float", (e) => {
      if (e.detail.id !== this.el.dataset.characterId) return
      const el = document.createElement("span")
      el.textContent = e.detail.label
      el.className = `floating-number ${e.detail.color === "red" ? "text-red-800" : "text-green-800"}`
      this.el.appendChild(el)
      el.addEventListener("animationend", () => el.remove(), {once: true})
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...BackpexHooks, CharacterEffects, BoardTileClasses}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

