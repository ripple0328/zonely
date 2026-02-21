export default {
  // ISO-2 to ISO-3 country code mapping (for common countries)
  iso2to3: {
    AF: "AFG", AL: "ALB", DZ: "DZA", AD: "AND", AO: "AGO", AG: "ATG", AR: "ARG", AM: "ARM", AU: "AUS", AT: "AUT",
    AZ: "AZE", BS: "BHS", BH: "BHR", BD: "BGD", BB: "BRB", BY: "BLR", BE: "BEL", BZ: "BLZ", BJ: "BEN", BT: "BTN",
    BO: "BOL", BA: "BIH", BW: "BWA", BR: "BRA", BN: "BRN", BG: "BGR", BF: "BFA", BI: "BDI", KH: "KHM", CM: "CMR",
    CA: "CAN", CV: "CPV", CF: "CAF", TD: "TCD", CL: "CHL", CN: "CHN", CO: "COL", KM: "COM", CG: "COG", CD: "COD",
    CR: "CRI", CI: "CIV", HR: "HRV", CU: "CUB", CY: "CYP", CZ: "CZE", DK: "DNK", DJ: "DJI", DM: "DMA", DO: "DOM",
    EC: "ECU", EG: "EGY", SV: "SLV", GQ: "GNQ", ER: "ERI", EE: "EST", ET: "ETH", FJ: "FJI", FI: "FIN", FR: "FRA",
    GA: "GAB", GM: "GMB", GE: "GEO", DE: "DEU", GH: "GHA", GR: "GRC", GD: "GRD", GT: "GTM", GN: "GIN", GW: "GNB",
    GY: "GUY", HT: "HTI", HN: "HND", HU: "HUN", IS: "ISL", IN: "IND", ID: "IDN", IR: "IRN", IQ: "IRQ", IE: "IRL",
    IL: "ISR", IT: "ITA", JM: "JAM", JP: "JPN", JO: "JOR", KZ: "KAZ", KE: "KEN", KI: "KIR", KP: "PRK", KR: "KOR",
    KW: "KWT", KG: "KGZ", LA: "LAO", LV: "LVA", LB: "LBN", LS: "LSO", LR: "LBR", LY: "LBY", LI: "LIE", LT: "LTU",
    LU: "LUX", MK: "MKD", MG: "MDG", MW: "MWI", MY: "MYS", MV: "MDV", ML: "MLI", MT: "MLT", MH: "MHL", MR: "MRT",
    MU: "MUS", MX: "MEX", FM: "FSM", MD: "MDA", MC: "MCO", MN: "MNG", ME: "MNE", MA: "MAR", MZ: "MOZ", MM: "MMR",
    NA: "NAM", NR: "NRU", NP: "NPL", NL: "NLD", NZ: "NZL", NI: "NIC", NE: "NER", NG: "NGA", NO: "NOR", OM: "OMN",
    PK: "PAK", PW: "PLW", PS: "PSE", PA: "PAN", PG: "PNG", PY: "PRY", PE: "PER", PH: "PHL", PL: "POL", PT: "PRT",
    QA: "QAT", RO: "ROU", RU: "RUS", RW: "RWA", KN: "KNA", LC: "LCA", VC: "VCT", WS: "WSM", SM: "SMR", ST: "STP",
    SA: "SAU", SN: "SEN", RS: "SRB", SC: "SYC", SL: "SLE", SG: "SGP", SK: "SVK", SI: "SVN", SB: "SLB", SO: "SOM",
    ZA: "ZAF", SS: "SSD", ES: "ESP", LK: "LKA", SD: "SDN", SR: "SUR", SZ: "SWZ", SE: "SWE", CH: "CHE", SY: "SYR",
    TW: "TWN", TJ: "TJK", TZ: "TZA", TH: "THA", TL: "TLS", TG: "TGO", TO: "TON", TT: "TTO", TN: "TUN", TR: "TUR",
    TM: "TKM", TV: "TUV", UG: "UGA", UA: "UKR", AE: "ARE", GB: "GBR", US: "USA", UY: "URY", UZ: "UZB", VU: "VUT",
    VA: "VAT", VE: "VEN", VN: "VNM", YE: "YEM", ZM: "ZMB", ZW: "ZWE", XK: "XKX", HK: "HKG", MO: "MAC", PR: "PRI",
  },

  mounted() {
    const countsIso2 = JSON.parse(this.el.dataset.countries || "{}")

    // Convert ISO-2 counts to ISO-3 for matching with GeoJSON
    // Store on `this` so it's accessible in event handlers
    this.counts = {}
    this.countsIso2 = countsIso2 // Keep original for debugging
    for (const [iso2, count] of Object.entries(countsIso2)) {
      const iso3 = this.iso2to3[iso2] || iso2
      this.counts[iso3] = count
    }

    if (!window.maplibregl) {
      this.el.innerHTML = "<div style=\"padding:16px;color:#6b7280\">Map failed to load (MapLibre missing)</div>"
      return
    }

    // Calculate max count for dynamic color scaling
    const maxCount = Math.max(...Object.values(this.counts), 1)

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

    this.popup = new maplibregl.Popup({
      closeButton: false,
      closeOnClick: false,
      offset: 12,
      className: "analytics-popup",
    })

    const self = this

    map.on("load", async () => {
      let geojson
      try {
        const res = await fetch("/images/countries.geo.json")
        geojson = await res.json()
      } catch (err) {
        self.el.innerHTML = "<div style=\"padding:16px;color:#6b7280\">Map failed to load (geojson fetch)</div>"
        return
      }

      // Add play count directly to GeoJSON features for data-driven styling
      // This avoids issues with feature state and string IDs
      geojson.features.forEach((feature) => {
        const iso3 = feature.id
        if (!iso3) return
        feature.properties.playCount = self.counts[iso3] || 0
      })

      map.addSource("countries", {
        type: "geojson",
        data: geojson,
      })

      // Dynamic color stops based on actual data range
      const colorStops = self.buildColorStops(maxCount)

      // Country fill layer with data-driven heatmap coloring
      map.addLayer({
        id: "countries-fill",
        type: "fill",
        source: "countries",
        paint: {
          "fill-color": [
            "interpolate",
            ["linear"],
            ["coalesce", ["get", "playCount"], 0],
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
        filter: ["==", ["get", "__never_match__"], ""],
      })

      // Hover interactions
      let hoveredId = null

      map.on("mousemove", "countries-fill", (e) => {
        if (!e.features?.length) return
        const feature = e.features[0]
        const name = feature.properties?.name || "Unknown"
        const count = feature.properties?.playCount || 0

        // Update highlight filter using country name (more reliable than id)
        if (name !== hoveredId) {
          hoveredId = name
          map.setFilter("countries-highlight", ["==", ["get", "name"], name])
        }

        map.getCanvas().style.cursor = "pointer"

        // Styled popup
        self.popup
          .setLngLat(e.lngLat)
          .setHTML(`
            <div style="font-family: system-ui, -apple-system, sans-serif; padding: 4px 0;">
              <div style="font-weight: 600; color: #1e293b; font-size: 13px; margin-bottom: 2px;">${name}</div>
              <div style="color: #6366f1; font-size: 14px; font-weight: 700;">${self.formatNumber(count)} <span style="font-weight: 400; color: #64748b; font-size: 12px;">plays</span></div>
            </div>
          `)
          .addTo(map)
      })

      map.on("mouseleave", "countries-fill", () => {
        hoveredId = null
        map.setFilter("countries-highlight", ["==", ["get", "__never_match__"], ""])
        map.getCanvas().style.cursor = ""
        self.popup.remove()
      })
    })

    this.map = map
  },

  // Build dynamic color stops using relative linear interpolation
  // Colors are evenly distributed across the actual data range [0, maxCount]
  // Returns flat array: [value1, color1, value2, color2, ...]
  buildColorStops(maxCount) {
    const noDataColor = "#f1f5f9" // slate-100 (no data)

    // Active indigo color palette (light to dark) for countries with plays
    const activeColors = [
      "#c7d2fe", // indigo-200 - lightest active
      "#a5b4fc", // indigo-300
      "#818cf8", // indigo-400
      "#6366f1", // indigo-500
      "#4f46e5", // indigo-600
      "#4338ca", // indigo-700 - darkest
    ]

    // Edge case: maxCount <= 1 — only two stops needed
    if (maxCount <= 1) {
      return [0, noDataColor, 1, activeColors[activeColors.length - 1]]
    }

    // Edge case: maxCount == 2
    if (maxCount === 2) {
      return [0, noDataColor, 1, activeColors[0], 2, activeColors[activeColors.length - 1]]
    }

    // General case: distribute active colors evenly between 1 and maxCount
    // First stop is always 0 → no-data color
    // Second stop is always 1 → lightest active color
    // Remaining active colors are evenly spaced up to maxCount
    const stops = [0, noDataColor]
    const numActiveColors = activeColors.length
    let lastValue = -1

    for (let i = 0; i < numActiveColors; i++) {
      // Evenly space from 1 to maxCount
      const value = Math.round(1 + (i / (numActiveColors - 1)) * (maxCount - 1))
      // MapLibre requires strictly ascending breakpoints — skip duplicates
      if (value > lastValue) {
        stops.push(value, activeColors[i])
        lastValue = value
      }
    }

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
