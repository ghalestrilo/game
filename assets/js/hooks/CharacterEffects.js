const floatCounters = {}

const CharacterEffects = {
  mounted() {
    this._onHit = (e) => {
      if (e.detail.id !== this.el.dataset.characterId) return
      const color = e.detail.color || "yellow"
      const colorClass = `character-hit-${color}`
      this.el.classList.remove("character-hit", "character-hit-red", "character-hit-green", "character-hit-blue", "character-hit-yellow")
      void this.el.offsetWidth // reflow to restart animation
      this.el.classList.add("character-hit", colorClass)
      this.el.addEventListener("animationend", () => {
        this.el.classList.remove("character-hit", colorClass)
      }, {once: true})
    }

    this._onFloat = (e) => {
      if (e.detail.id !== this.el.dataset.characterId) return
      const id = e.detail.id
      clearTimeout(floatCounters[id]?.timer)
      const index = floatCounters[id]?.count ?? 0
      floatCounters[id] = {
        count: index + 1,
        timer: setTimeout(() => { delete floatCounters[id] }, 600)
      }
      const el = document.createElement("span")
      el.textContent = e.detail.label
      el.className = `floating-number ${e.detail.color === "red" ? "text-red-800" : "text-green-800"}`
      el.style.marginTop = `${index * -1.8}rem`
      this.el.appendChild(el)
      el.addEventListener("animationend", () => el.remove(), {once: true})
    }

    window.addEventListener("phx:hit", this._onHit)
    window.addEventListener("phx:float", this._onFloat)
  },

  destroyed() {
    window.removeEventListener("phx:hit", this._onHit)
    window.removeEventListener("phx:float", this._onFloat)
  }
}

export default CharacterEffects
