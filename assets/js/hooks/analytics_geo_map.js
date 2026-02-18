export default {
  mounted() {
    const counts = JSON.parse(this.el.dataset.countries || "{}")

    if (!window.maplibregl) {
      this.el.innerHTML = "<div style=\"padding:16px;color:#6b7280\">Map failed to load (MapLibre missing)</div>"
      return
    }

    // Calculate max count for dynamic color scaling
    const maxCount = Math.max(...Object.values(counts), 1)

    let map

    try {
      // Clean, minimal map style with light gray landmass
      map = new maplibregl.Map({
        container: this.el,
        style: {
          version: 8,
          sources: {},
          layers: [
            {
              id: "background",
              type: "background",
              paint: { "background-color": "#e8eef4" }, // Light blue-gray ocean
            },
          ],
        },
        center: [0, 20],
        zoom: 1.3,
        attributionControl: false,
        interactive: true,
      })
    } catch (error) {
      console.error("Error initializing analytics geo map:", error)
      this.el.innerHTML = "<div style=\"padding:16px;color:#6b7280\">Map failed to load</div>"
      return
    }

    map.scrollZoom.disable()
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "bottom-right")

    const popup = new maplibregl.Popup({
      closeButton: false,
      closeOnClick: false,
      offset: 12,
      className: "analytics-popup",
    })

    map.on("load", async () => {
      let geojson
      try {
        const res = await fetch("/images/countries.geo.json")
        geojson = await res.json()
      } catch (err) {
        this.el.innerHTML = "<div style=\"padding:16px;color:#6b7280\">Map failed to load (geojson fetch)</div>"
        return
      }

      // Assign feature IDs based on ISO code
      geojson.features.forEach((feature) => {
        const iso = feature.properties.iso_a2 || feature.properties.ISO_A2
        if (iso) feature.id = iso
      })

      map.addSource("countries", { type: "geojson", data: geojson })

      // Dynamic color stops based on actual data range
      // Using indigo color palette to match dashboard design
      const colorStops = this.buildColorStops(maxCount)

      // Country fill layer with dynamic heatmap coloring
      map.addLayer({
        id: "countries-fill",
        type: "fill",
        source: "countries",
        paint: {
          "fill-color": [
            "interpolate",
            ["linear"],
            ["coalesce", ["feature-state", "count"], 0],
            ...colorStops,
          ],
          "fill-opacity": 0.85,
        },
      })

      // Subtle country borders
      map.addLayer({
        id: "countries-outline",
        type: "line",
        source: "countries",
        paint: {
          "line-color": "#94a3b8",
          "line-width": 0.4,
        },
      })

      // Highlight border on hover
      map.addLayer({
        id: "countries-highlight",
        type: "line",
        source: "countries",
        paint: {
          "line-color": "#4f46e5",
          "line-width": 2,
        },
        filter: ["==", ["get", "iso_a2"], ""],
      })

      // Set feature state for each country with play count
      geojson.features.forEach((feature) => {
        const iso = feature.properties.iso_a2 || feature.properties.ISO_A2
        if (!iso) return
        const count = counts[iso] || 0
        map.setFeatureState(
          { source: "countries", id: feature.id },
          { count }
        )
      })

      // Hover interactions
      map.on("mousemove", "countries-fill", (e) => {
        if (!e.features?.length) return
        const feature = e.features[0]
        const iso = feature.properties.iso_a2 || feature.properties.ISO_A2
        const name = feature.properties.name || feature.properties.ADMIN || iso
        const count = counts[iso] || 0

        // Update highlight filter
        map.setFilter("countries-highlight", ["==", ["get", "iso_a2"], iso])

        map.getCanvas().style.cursor = "pointer"

        // Styled popup
        popup
          .setLngLat(e.lngLat)
          .setHTML(`
            <div style="font-family: system-ui, -apple-system, sans-serif; padding: 4px 0;">
              <div style="font-weight: 600; color: #1e293b; font-size: 13px; margin-bottom: 2px;">${name}</div>
              <div style="color: #6366f1; font-size: 14px; font-weight: 700;">${this.formatNumber(count)} <span style="font-weight: 400; color: #64748b; font-size: 12px;">plays</span></div>
            </div>
          `)
          .addTo(map)
      })

      map.on("mouseleave", "countries-fill", () => {
        map.setFilter("countries-highlight", ["==", ["get", "iso_a2"], ""])
        map.getCanvas().style.cursor = ""
        popup.remove()
      })
    })

    this.map = map
  },

  // Build dynamic color stops based on max count
  // Returns flat array: [value1, color1, value2, color2, ...]
  buildColorStops(maxCount) {
    // Indigo color palette (light to dark)
    const colors = [
      "#f1f5f9", // 0: slate-100 (no data)
      "#e0e7ff", // ~10%: indigo-100
      "#c7d2fe", // ~25%: indigo-200
      "#a5b4fc", // ~40%: indigo-300
      "#818cf8", // ~60%: indigo-400
      "#6366f1", // ~80%: indigo-500
      "#4338ca", // 100%: indigo-700
    ]

    // Calculate breakpoints
    const stops = [
      0, colors[0],
      Math.max(1, Math.floor(maxCount * 0.05)), colors[1],
      Math.max(2, Math.floor(maxCount * 0.15)), colors[2],
      Math.max(3, Math.floor(maxCount * 0.30)), colors[3],
      Math.max(4, Math.floor(maxCount * 0.50)), colors[4],
      Math.max(5, Math.floor(maxCount * 0.75)), colors[5],
      maxCount, colors[6],
    ]

    return stops
  },

  formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + "M"
    if (num >= 1000) return (num / 1000).toFixed(1) + "K"
    return num.toString()
  },

  destroyed() {
    if (this.map) this.map.remove()
  },
}
