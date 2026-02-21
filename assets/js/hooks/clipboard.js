/**
 * Clipboard hook - copies data-clipboard-text to clipboard on click.
 */
const Clipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const text = this.el.dataset.clipboardText
      if (text && navigator.clipboard) {
        navigator.clipboard.writeText(text).catch(() => {
          // Fallback for older browsers
          const ta = document.createElement("textarea")
          ta.value = text
          ta.style.position = "fixed"
          ta.style.opacity = "0"
          document.body.appendChild(ta)
          ta.select()
          document.execCommand("copy")
          document.body.removeChild(ta)
        })
      }
    })
  }
}

export default Clipboard

