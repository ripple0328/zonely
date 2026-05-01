function copyText(text) {
  if (!text) {
    return Promise.resolve()
  }

  if (navigator.clipboard) {
    return navigator.clipboard.writeText(text).catch(() => fallbackCopyText(text))
  }

  return fallbackCopyText(text)
}

function fallbackCopyText(text) {
  const ta = document.createElement("textarea")
  ta.value = text
  ta.style.position = "fixed"
  ta.style.opacity = "0"
  document.body.appendChild(ta)
  ta.select()
  document.execCommand("copy")
  document.body.removeChild(ta)

  return Promise.resolve()
}

function temporarilyConfirmCopy(el) {
  const label = el.querySelector("[data-copy-label]")

  if (!label || el.dataset.copyResetTimer) {
    return
  }

  const originalText = label.textContent
  label.textContent = el.dataset.copySuccessText || "Copied"
  el.dataset.copyResetTimer = "true"

  window.setTimeout(() => {
    label.textContent = originalText
    delete el.dataset.copyResetTimer
  }, 1600)
}

export function setupClipboardButtons(root = document) {
  const buttons = root.querySelectorAll("[data-clipboard-text]")

  buttons.forEach((button) => {
    if (button.dataset.clipboardBound === "true") {
      return
    }

    button.dataset.clipboardBound = "true"
    button.addEventListener("click", () => {
      copyText(button.dataset.clipboardText)
        .then(() => temporarilyConfirmCopy(button))
        .catch(() => {})
    })
  })
}

const Clipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      copyText(this.el.dataset.clipboardText)
        .then(() => temporarilyConfirmCopy(this.el))
        .catch(() => {})
    })
  }
}

export default Clipboard
