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
    const counts = {}
    for (const [iso2, count] of Object.entries(countsIso2)) {
      const iso3 = this.iso2to3[iso2] || iso2
      counts[iso3] = count
    }

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

      // Use feature.id (ISO-3) directly - it's already set in the GeoJSON
      map.addSource("countries", { type: "geojson", data: geojson, promoteId: "id" })

      // Dynamic color stops based on actual data range
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
        filter: ["==", ["id"], ""],
      })

      // Set feature state for each country with play count using ISO-3 IDs
      geojson.features.forEach((feature) => {
        const iso3 = feature.id
        if (!iso3) return
        const count = counts[iso3] || 0
        map.setFeatureState(
          { source: "countries", id: iso3 },
          { count }
        )
      })

      // Hover interactions
      map.on("mousemove", "countries-fill", (e) => {
        if (!e.features?.length) return
        const feature = e.features[0]
        const iso3 = feature.id
        const name = feature.properties.name || iso3
        const count = counts[iso3] || 0

        // Update highlight filter
        map.setFilter("countries-highlight", ["==", ["id"], iso3])

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
        map.setFilter("countries-highlight", ["==", ["id"], ""])
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
