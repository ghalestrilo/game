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

const CharacterEffects = {
  mounted() {
    window.addEventListener("phx:hit", (e) => {
      if (e.detail.id !== this.el.dataset.characterId) return
      this.el.classList.remove("character-hit")
      void this.el.offsetWidth // reflow to restart animation
      this.el.classList.add("character-hit")
      this.el.addEventListener("animationend", () => {
        this.el.classList.remove("character-hit")
      }, {once: true})
    })

    window.addEventListener("phx:float", (e) => {
      if (e.detail.id !== this.el.dataset.characterId) return
      const el = document.createElement("span")
      el.textContent = e.detail.label
      el.className = `floating-number ${e.detail.color === "red" ? "text-red-400" : "text-green-400"}`
      this.el.appendChild(el)
      el.addEventListener("animationend", () => el.remove(), {once: true})
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...BackpexHooks, CharacterEffects}
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

