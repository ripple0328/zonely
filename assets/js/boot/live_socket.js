import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

export function initLiveSocket(hooks) {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""
  const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: {_csrf_token: csrfToken},
    hooks
  })

  // connect if there are any LiveViews on the page
  liveSocket.connect()

  // expose liveSocket on window for web console debug logs and latency simulation
  window.liveSocket = liveSocket
  return liveSocket
}


