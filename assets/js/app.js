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

// Setup simple audio functionality first to create AudioHook
setupSimpleAudio()

// Register hooks in a dedicated object to avoid the legacy inline Hooks
const LV_HOOKS = { TeamMap, TimeScrubber, LiveClock, AudioHook: window.AudioHook }

// TimeScrubber handled via ./hooks/time_scrubber

// Setup topbar and connect LiveView
initTopbar()
const liveSocket = initLiveSocket(LV_HOOKS)

// expose liveSocket helpers in console docs
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// >> liveSocket.disableLatencySim()