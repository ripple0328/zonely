const COMMIT_THROTTLE_MS = 250

const PreviewRail = {
  mounted() {
    this.lastPushedValue = null
    this.pendingValue = this.el.value
    this.throttleTimer = null

    this.boundHandleInput = this.handleInput.bind(this)
    this.boundCommit = this.commitCurrentValue.bind(this)
    this.boundStopMapGesture = this.stopMapGesture.bind(this)
    this.boundHandleKeyup = this.handleKeyup.bind(this)

    this.el.addEventListener('input', this.boundHandleInput, { capture: true })
    this.el.addEventListener('change', this.boundCommit, { capture: true })
    this.el.addEventListener('pointerdown', this.boundStopMapGesture, { capture: true })
    this.el.addEventListener('pointermove', this.boundStopMapGesture, { capture: true })
    this.el.addEventListener('pointerup', this.boundCommit, { capture: true })
    this.el.addEventListener('touchstart', this.boundStopMapGesture, { capture: true, passive: false })
    this.el.addEventListener('touchmove', this.boundStopMapGesture, { capture: true, passive: false })
    this.el.addEventListener('touchend', this.boundCommit, { capture: true })
    this.el.addEventListener('keyup', this.boundHandleKeyup, { capture: true })
  },

  updated() {
    this.pendingValue = this.el.value
    this.lastPushedValue = String(this.el.value || '0')
  },

  destroyed() {
    if (this.throttleTimer) clearTimeout(this.throttleTimer)

    this.el.removeEventListener('input', this.boundHandleInput, { capture: true })
    this.el.removeEventListener('change', this.boundCommit, { capture: true })
    this.el.removeEventListener('pointerdown', this.boundStopMapGesture, { capture: true })
    this.el.removeEventListener('pointermove', this.boundStopMapGesture, { capture: true })
    this.el.removeEventListener('pointerup', this.boundCommit, { capture: true })
    this.el.removeEventListener('touchstart', this.boundStopMapGesture, { capture: true })
    this.el.removeEventListener('touchmove', this.boundStopMapGesture, { capture: true })
    this.el.removeEventListener('touchend', this.boundCommit, { capture: true })
    this.el.removeEventListener('keyup', this.boundHandleKeyup, { capture: true })
  },

  handleInput(event) {
    event.stopPropagation()
    this.pendingValue = this.el.value

    if (this.throttleTimer) return

    this.throttleTimer = window.setTimeout(() => {
      this.throttleTimer = null
      this.pushPreviewValue(this.pendingValue)
    }, COMMIT_THROTTLE_MS)
  },

  handleKeyup(event) {
    if (!this.isCommitKey(event.key)) return

    this.commitCurrentValue(event)
  },

  commitCurrentValue(event) {
    if (event) event.stopPropagation()

    if (this.throttleTimer) {
      window.clearTimeout(this.throttleTimer)
      this.throttleTimer = null
    }

    this.pendingValue = this.el.value
    this.pushPreviewValue(this.pendingValue)
  },

  pushPreviewValue(value) {
    const normalizedValue = String(value || '0')

    if (normalizedValue === this.lastPushedValue) return

    this.lastPushedValue = normalizedValue
    this.pushEvent('preview_time', { offset_minutes: normalizedValue })
  },

  stopMapGesture(event) {
    event.stopPropagation()
  },

  isCommitKey(key) {
    return ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown'].includes(key)
  }
}

export default PreviewRail
