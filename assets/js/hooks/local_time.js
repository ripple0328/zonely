// LocalTime hook - converts UTC timestamp to user's local time
// Updates whenever the data-utc attribute changes (e.g., on LiveView re-renders)

const LocalTime = {
  mounted() {
    this.updateTime()
  },

  updated() {
    this.updateTime()
  },

  updateTime() {
    const utcTimestamp = this.el.dataset.utc
    if (!utcTimestamp) return

    try {
      const date = new Date(utcTimestamp)
      const formatter = new Intl.DateTimeFormat('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      })
      this.el.textContent = formatter.format(date)
    } catch (error) {
      console.error('Error formatting local time:', error)
      this.el.textContent = '--:--'
    }
  }
}

export default LocalTime

