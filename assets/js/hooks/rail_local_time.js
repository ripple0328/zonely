const timeFormatter = new Intl.DateTimeFormat(undefined, {
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23'
})

const dateTimeFormatter = new Intl.DateTimeFormat(undefined, {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23'
})

function parseDate(value) {
  if (!value) return null

  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

function formatTime(date) {
  return timeFormatter.format(date)
}

function formatDateTime(date) {
  return dateTimeFormatter.format(date)
}

function localDateKey(date) {
  return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`
}

function daySuffix(start, end) {
  if (localDateKey(start) === localDateKey(end)) return ''

  const startDate = new Date(start.getFullYear(), start.getMonth(), start.getDate())
  const endDate = new Date(end.getFullYear(), end.getMonth(), end.getDate())
  const diffDays = Math.round((endDate.getTime() - startDate.getTime()) / 86400000)

  if (diffDays === 1) return ' tomorrow'
  if (diffDays > 1) return ` +${diffDays} days`
  return ''
}

const RailLocalTime = {
  mounted() {
    this.updateLabels()
  },

  updated() {
    this.updateLabels()
  },

  updateLabels() {
    const start = parseDate(this.el.dataset.windowStartAt)
    const end = parseDate(this.el.dataset.windowEndAt)
    const effective = parseDate(this.el.dataset.effectiveAt)
    const previewActive = this.el.dataset.previewActive === 'true'
    const contextLabel = this.el.dataset.railContextLabel || 'Availability'

    if (!start || !end || !effective) return

    const rangeEl = this.el.querySelector('[data-rail-local-range]')
    if (rangeEl) {
      rangeEl.textContent = `${formatTime(start)} to ${formatTime(end)}${daySuffix(start, end)}`
    }

    const statusEl = this.el.querySelector('[data-rail-local-status]')
    if (statusEl) {
      statusEl.textContent = previewActive
        ? `${contextLabel} preview at ${formatDateTime(effective)}.`
        : `${contextLabel} live at ${formatTime(effective)}. Explore the next 24 hours.`
    }

    const control = this.el.querySelector('#map-time-rail-control')
    if (control) {
      control.setAttribute(
        'aria-valuetext',
        previewActive
          ? `${contextLabel} preview at ${formatDateTime(effective)}`
          : `${contextLabel} live now, ${formatTime(effective)}`
      )
    }

    const ticks = Array.from(this.el.querySelectorAll('[data-local-time-at]'))
    ticks.forEach(tick => {
      const tickAt = parseDate(tick.dataset.localTimeAt)
      if (!tickAt) return

      tick.textContent = `${formatTime(tickAt)}${daySuffix(start, tickAt)}`
    })

    const tickContainer = this.el.querySelector('#map-time-rail-ticks')
    if (tickContainer) {
      tickContainer.setAttribute(
        'aria-label',
        `Bounded from live now at ${formatTime(start)} through ${formatTime(end)}${daySuffix(start, end)}`
      )
    }
  }
}

export default RailLocalTime
