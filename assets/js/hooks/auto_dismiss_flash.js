const AutoDismissFlash = {
  mounted() {
    this.timer = window.setTimeout(() => {
      this.pushEvent("lv:clear-flash", {key: this.el.dataset.flashKind || "info"})
      this.el.style.display = "none"
    }, 2600)
  },

  destroyed() {
    if (this.timer) window.clearTimeout(this.timer)
  }
}

export default AutoDismissFlash
