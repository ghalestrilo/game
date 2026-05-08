const SERVER_CLASSES = [
  "ring-2", "ring-inset", "ring-error/20", "bg-error/5",
  "scale-[1.05]",
  "opacity-40",
  "bg-warning/10",
  "!bg-success/30",
  "blast-preview"
]

const BoardTileClasses = {
  mounted() {
    this._applyAll()
    this._bindHover()
    this.handleEvent("highlight-tile", ({ coord }) => this._highlightCoord(coord))
  },
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

  _highlightCoord(coord) {
    const blastMap = JSON.parse(this.el.dataset.blastMap || "{}")
    const tiles = this._tiles()
    this.el.querySelectorAll(".blast-preview").forEach(el => el.classList.remove("blast-preview"))
    ;(blastMap[coord] || [coord]).forEach(c => tiles[c]?.classList.add("blast-preview"))
  },

  _bindHover() {
    this.el.addEventListener("mouseover", e => {
      const tile = e.target.closest("[data-coord]")
      if (!tile) return
      this._highlightCoord(tile.dataset.coord)
    })

    this.el.addEventListener("mouseleave", () => {
      this.el.querySelectorAll(".blast-preview").forEach(el => el.classList.remove("blast-preview"))
    })
  }
}

export default BoardTileClasses
