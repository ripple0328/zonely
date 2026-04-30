const FocusTeamOrbit = {
  mounted() {
    this.handleEvent("focus_team_orbit", () => {
      const panel = document.getElementById("team-orbit-panel")
      if (!panel || panel.hidden) return

      panel.focus({ preventScroll: true })
    })
  }
}

export default FocusTeamOrbit
