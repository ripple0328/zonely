export default {
  mounted() {
    const apiKey = this.el.dataset.apiKey
    const counts = JSON.parse(this.el.dataset.countries || "{}")

    if (!window.maplibregl) {
      this.el.innerHTML = "<div style=\"padding:16px;color:#6b7280\">Map failed to load (MapLibre missing)</div>"
      return
    }

    let map

    try {
      // Use a simple OpenStreetMap raster style (no external MapTiler dependency)
      map = new maplibregl.Map({
        container: this.el,
        style: {
          version: 8,
          sources: {
            "simple-tiles": {
              type: "raster",
              tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
              tileSize: 256,
              attribution: "© OpenStreetMap contributors",
            },
          },
          layers: [
            {
              id: "background",
              type: "background",
              paint: { "background-color": "#f8f9fa" },
            },
            {
              id: "simple-tiles-layer",
              type: "raster",
              source: "simple-tiles",
              paint: { "raster-opacity": 0.9 },
            },
          ],
        },
        center: [0, 20],
        zoom: 1.2,
        attributionControl: false,
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
      offset: 10,
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

      geojson.features.forEach((feature) => {
        const iso = feature.properties.iso_a2 || feature.properties.ISO_A2
        if (iso) feature.id = iso
      })

      map.addSource("countries", { type: "geojson", data: geojson })

      map.addLayer({
        id: "countries-fill",
        type: "fill",
        source: "countries",
        paint: {
          "fill-color": [
            "interpolate",
            ["linear"],
            ["coalesce", ["feature-state", "count"], 0],
            0,
            "#e5e7eb",
            1,
            "#bfdbfe",
            5,
            "#60a5fa",
            10,
            "#2563eb",
            20,
            "#1e3a8a",
          ],
          "fill-opacity": 0.8,
        },
      })

      map.addLayer({
        id: "countries-outline",
        type: "line",
        source: "countries",
        paint: {
          "line-color": "#9ca3af",
          "line-width": 0.5,
        },
      })

      geojson.features.forEach((feature) => {
        const iso = feature.properties.iso_a2 || feature.properties.ISO_A2
        if (!iso) return
        const count = counts[iso] || 0
        map.setFeatureState(
          { source: "countries", id: feature.id },
          { count }
        )
      })

      map.on("mousemove", "countries-fill", (e) => {
        if (!e.features?.length) return
        const feature = e.features[0]
        const iso = feature.properties.iso_a2 || feature.properties.ISO_A2
        const name = feature.properties.name || feature.properties.ADMIN || iso
        const count = counts[iso] || 0

        map.getCanvas().style.cursor = "pointer"
        popup
          .setLngLat(e.lngLat)
          .setHTML(`<div style=\"font-weight:600\">${name}</div><div>${count} plays</div>`)
          .addTo(map)
      })

      map.on("mouseleave", "countries-fill", () => {
        map.getCanvas().style.cursor = ""
        popup.remove()
      })
    })

    this.map = map
  },

  destroyed() {
    if (this.map) this.map.remove()
  },
}
