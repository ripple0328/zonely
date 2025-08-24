import topbar from "../../vendor/topbar"

export function initTopbar() {
  // Configure topbar appearance
  topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
  
  // Show progress bar on live navigation and form submits
  window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
  window.addEventListener("phx:page-loading-stop", _info => topbar.hide())
  
  // Make topbar available globally for any other usage
  window.topbar = topbar
}


