// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {initLiveSocket} from "./boot/live_socket"
import {initTopbar} from "./boot/topbar"
// Import minimal audio functionality
import {setupSimpleAudio} from "./simple-audio"
// Extracted hooks
import TeamMap from "./hooks/team_map"
import TimeScrubber from "./hooks/time_scrubber"
import LiveClock from "./hooks/live_clock"
import LocalTime from "./hooks/local_time"
import AnalyticsGeoMap from "./hooks/analytics_geo_map"

// Setup simple audio functionality first to create AudioHook
setupSimpleAudio()

// Register hooks in a dedicated object to avoid the legacy inline Hooks
const LV_HOOKS = { TeamMap, TimeScrubber, LiveClock, LocalTime, AnalyticsGeoMap, AudioHook: window.AudioHook }

// TimeScrubber handled via ./hooks/time_scrubber

// Setup topbar and connect LiveView
initTopbar()
const liveSocket = initLiveSocket(LV_HOOKS)

// Metric flash on value change - enhanced for live dashboard feel
function initMetricFlash() {
  const valueFlashClass = 'metric-flash'
  const cardFlashClass = 'metric-card-flash'
  const rankFlashClass = 'rank-item-flash'
  const observedElements = new WeakSet()

  const observe = (root) => {
    // Observe metric value elements (the number itself)
    root.querySelectorAll('[data-metric-value]').forEach((el) => {
      if (observedElements.has(el)) return
      observedElements.add(el)

      const obs = new MutationObserver((mutations) => {
        // Only flash if content actually changed
        const hasChange = mutations.some(m =>
          m.type === 'childList' || m.type === 'characterData'
        )
        if (!hasChange) return

        // Flash the value itself
        el.classList.remove(valueFlashClass)
        void el.offsetWidth // Force reflow
        el.classList.add(valueFlashClass)
        setTimeout(() => el.classList.remove(valueFlashClass), 800)

        // Flash the parent card if it exists
        const card = el.closest('[data-metric-card]')
        if (card) {
          card.classList.remove(cardFlashClass)
          void card.offsetWidth
          card.classList.add(cardFlashClass)
          setTimeout(() => card.classList.remove(cardFlashClass), 1000)
        }
      })
      obs.observe(el, { childList: true, characterData: true, subtree: true })
    })

    // Observe ranked list items
    root.querySelectorAll('[data-rank-item]').forEach((el) => {
      if (observedElements.has(el)) return
      observedElements.add(el)

      const obs = new MutationObserver((mutations) => {
        const hasChange = mutations.some(m =>
          m.type === 'childList' || m.type === 'characterData'
        )
        if (!hasChange) return

        el.classList.remove(rankFlashClass)
        void el.offsetWidth
        el.classList.add(rankFlashClass)
        setTimeout(() => el.classList.remove(rankFlashClass), 800)
      })
      obs.observe(el, { childList: true, characterData: true, subtree: true })
    })
  }

  // Initial observation
  observe(document)

  // Re-observe after LiveView updates
  if (typeof liveSocket !== 'undefined') {
    liveSocket.onViewUpdate(() => observe(document))
  }
}

initMetricFlash()

// expose liveSocket helpers in console docs
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// >> liveSocket.disableLatencySim()