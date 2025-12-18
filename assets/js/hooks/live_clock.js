// LiveClock hook - displays and updates the current time in a specific timezone

const LiveClock = {
  mounted() {
    this.timezone = this.el.dataset.timezone || 'UTC'
    this.updateTime()

    // Update every second
    this.interval = setInterval(() => {
      this.updateTime()
    }, 1000)
  },

  updated() {
    // Update timezone if it changes
    const newTimezone = this.el.dataset.timezone
    if (newTimezone && newTimezone !== this.timezone) {
      this.timezone = newTimezone
      this.updateTime()
    }
  },

  destroyed() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  },

  updateTime() {
    try {
      const now = new Date()
      const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: this.timezone,
        hour: 'numeric',
        minute: '2-digit',
        second: '2-digit',
        hour12: true
      })

      this.el.textContent = formatter.format(now)
    } catch (error) {
      console.error('Error formatting time:', error)
      this.el.textContent = 'Invalid timezone'
    }
  }
}

export default LiveClock
