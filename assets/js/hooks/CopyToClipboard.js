const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const target = document.getElementById(this.el.dataset.target)
      navigator.clipboard.writeText(target.value)
      const original = this.el.innerHTML
      this.el.innerHTML = "Copied!"
      setTimeout(() => { this.el.innerHTML = original }, 1500)
    })
  }
}

export default CopyToClipboard
