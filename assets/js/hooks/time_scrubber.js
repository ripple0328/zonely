// TimeScrubber hook for the overlap heatmap time selection
// Extracted from app.js to keep the main bundle modular and smaller

const TimeScrubber = {
  mounted() {
    console.log('TimeScrubber hook mounted!')

    this.isDragging = false
    this.throttleTimeout = null
    this.dragMode = null // 'new', 'start-handle', 'end-handle', 'middle'
    this.currentSelection = null // {left: 0.2, width: 0.3}

    // Store global reference for marker updates
    if (!window.markersById) {
      window.markersById = {}
    }

    this.handleEvent("overlap_update", ({statuses, highlighted_timezones}) => {
      // Reset all when requested
      if (this.el && statuses && Object.keys(statuses).length === 0) {
        document.querySelectorAll('[data-user-id]')
          .forEach(el => el.classList.remove('state-working', 'state-edge', 'state-off'))
      }
      // Update marker states
      for (const [id, state] of Object.entries(statuses || {})) {
        const markerEl = document.querySelector(`[data-user-id="${id}"]`)
        if (!markerEl) continue
        markerEl.classList.remove('state-working', 'state-edge', 'state-off')
        if (state === 2) markerEl.classList.add('state-working')
        else if (state === 1) markerEl.classList.add('state-edge')
        else markerEl.classList.add('state-off')
      }
    })

    // Rehydrate selection when server instructs
    this.handleEvent("time_selection_set", (payload) => {
      console.log('TimeScrubber: time_selection_set', payload)
      const selection = document.getElementById('scrubber-selection')
      const display = document.getElementById('time-display')
      const durationDisplay = document.getElementById('duration-display')
      const instruction = document.getElementById('instruction-text')

      if (payload.clear) {
        this.currentSelection = null
        if (selection) selection.classList.add('hidden')
        if (instruction) instruction.classList.remove('hidden')
        if (display) display.textContent = 'No selection'
        if (durationDisplay) durationDisplay.textContent = 'Drag to select'
        return
      }

      const { a_frac, b_frac } = payload
      if (typeof a_frac === 'number' && typeof b_frac === 'number') {
        const left = Math.max(0, Math.min(1, a_frac))
        const width = Math.max(0.02, Math.min(1, b_frac) - left)
        this.currentSelection = { left, width }
        this.updateSelectionDisplay(left, width)
        // Also push a hover update to refresh avatars immediately
        try { this.pushEvent('hover_range', { a_frac: left, b_frac: left + width }) } catch {}
      }
    })

    // Mouse/touch event handlers
    this.el.addEventListener('mousedown', this.startDrag.bind(this))
    this.el.addEventListener('mousemove', this.handleMove.bind(this))
    this.el.addEventListener('mouseup', this.endDrag.bind(this))
    this.el.addEventListener('mouseleave', this.endDrag.bind(this))

    // Touch events for mobile
    this.el.addEventListener('touchstart', this.startDrag.bind(this))
    this.el.addEventListener('touchmove', this.handleMove.bind(this))
    this.el.addEventListener('touchend', this.endDrag.bind(this))
  },

  startDrag(e) {
    const relativeX = this.getRelativeX(e)

    // Determine what we're dragging
    if (this.currentSelection) {
      const tolerance = 0.03 // 3% tolerance for handle detection
      const selectionLeft = this.currentSelection.left
      const selectionRight = this.currentSelection.left + this.currentSelection.width

      if (Math.abs(relativeX - selectionLeft) < tolerance) {
        // Dragging start handle
        this.dragMode = 'start-handle'
        this.dragOffset = relativeX - selectionLeft
      } else if (Math.abs(relativeX - selectionRight) < tolerance) {
        // Dragging end handle
        this.dragMode = 'end-handle'
        this.dragOffset = relativeX - selectionRight
      } else if (relativeX >= selectionLeft && relativeX <= selectionRight) {
        // Dragging middle (move entire selection)
        this.dragMode = 'middle'
        this.dragOffset = relativeX - selectionLeft
      } else {
        // Create new selection
        this.dragMode = 'new'
        this.startX = relativeX
        this.currentSelection = null
      }
    } else {
      // No existing selection - create new
      this.dragMode = 'new'
      this.startX = relativeX
    }

    this.isDragging = true
    e.preventDefault()
  },

  handleMove(e) {
    if (!this.isDragging) return

    const currentX = this.getRelativeX(e)
    let newLeft, newWidth

    switch (this.dragMode) {
      case 'new':
        newLeft = Math.min(this.startX, currentX)
        newWidth = Math.abs(currentX - this.startX)
        break

      case 'start-handle':
        const adjustedStart = currentX - this.dragOffset
        const originalRight = this.currentSelection.left + this.currentSelection.width
        newLeft = Math.min(adjustedStart, originalRight - 0.02) // Minimum 2% width
        newWidth = originalRight - newLeft
        break

      case 'end-handle':
        const adjustedEnd = currentX - this.dragOffset
        newLeft = this.currentSelection.left
        newWidth = Math.max(0.02, adjustedEnd - newLeft) // Minimum 2% width
        break

      case 'middle':
        const draggedLeft = currentX - this.dragOffset
        newLeft = Math.max(0, Math.min(1 - this.currentSelection.width, draggedLeft))
        newWidth = this.currentSelection.width
        break
    }

    // Update current selection
    this.currentSelection = { left: newLeft, width: newWidth }
    this.updateSelectionDisplay(newLeft, newWidth)

    // Throttle hover_range events
    if (this.throttleTimeout) return
    this.throttleTimeout = setTimeout(() => {
      try {
        const a_frac = newLeft
        const b_frac = newLeft + newWidth
        this.pushEvent("hover_range", {a_frac, b_frac})
      } catch (error) {
        console.warn("Failed to push hover_range event:", error)
      }
      this.throttleTimeout = null
    }, 80) // ~12fps throttling

    e.preventDefault()
  },

  endDrag(e) {
    if (!this.isDragging) return
    this.isDragging = false

    if (this.currentSelection) {
      try {
        const a_frac = this.currentSelection.left
        const b_frac = this.currentSelection.left + this.currentSelection.width
        this.pushEvent("commit_range", {a_frac, b_frac})
      } catch (error) {
        console.warn("Failed to push commit_range event:", error)
      }
    }

    e.preventDefault()
  },

  getRelativeX(e) {
    const rect = this.el.getBoundingClientRect()
    const x = e.type.startsWith('touch') ? e.touches[0]?.clientX || e.changedTouches[0]?.clientX : e.clientX
    return Math.max(0, Math.min(1, (x - rect.left) / rect.width))
  },

  updateSelectionDisplay(left, width) {
    const selection = document.getElementById('scrubber-selection')
    const display = document.getElementById('time-display')
    const durationDisplay = document.getElementById('duration-display')
    const instruction = document.getElementById('instruction-text')

    if (width > 0.02) { // Show selection if wide enough (increased threshold)
      selection.style.left = `${left * 100}%`
      selection.style.width = `${width * 100}%`
      selection.classList.remove('hidden')
      instruction.classList.add('hidden') // Hide instruction when selecting

      // Update time display with better formatting
      const startHour = Math.floor(left * 24)
      const endHour = Math.floor((left + width) * 24)

      const formatHour = (h) => {
        if (h >= 24) h = 23 // Cap at 23
        if (h === 0) return '12:00 AM'
        if (h < 12) return `${h}:00 AM`
        if (h === 12) return '12:00 PM'
        return `${h - 12}:00 PM`
      }

      const duration = endHour - startHour
      const durationText = duration === 1 ? '1 hour window' : `${duration} hour window`

      display.textContent = `${formatHour(startHour)} - ${formatHour(endHour)}`
      if (durationDisplay) {
        durationDisplay.textContent = durationText
      }
    } else {
      selection.classList.add('hidden')
      instruction.classList.remove('hidden') // Show instruction when not selecting
      display.textContent = 'No selection'
      if (durationDisplay) {
        durationDisplay.textContent = 'Drag to select'
      }
    }
  },

  destroyed() {
    if (this.throttleTimeout) {
      clearTimeout(this.throttleTimeout)
    }
  }
}

export default TimeScrubber


