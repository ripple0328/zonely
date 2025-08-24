// TeamMap hook (simplified) for MapLibre GL JS integration
// Focused on LiveView-driven UI: clicking markers triggers server-side modal

const TeamMap = {
  mounted() {
    console.log('TeamMap hook mounted!')

    // Inform LiveView of the viewer's IANA timezone for correct overlap calculations
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Etc/UTC'
      this.pushEvent('set_viewer_tz', { tz })
    } catch (_e) {
      this.pushEvent('set_viewer_tz', { tz: 'Etc/UTC' })
    }

    const users = JSON.parse(this.el.dataset.users || '[]')

    // Initialize MapLibre GL JS map (OSM raster)
    let map
    try {
      map = new maplibregl.Map({
        container: this.el,
        style: {
          version: 8,
          sources: {
            'simple-tiles': {
              type: 'raster',
              tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
              tileSize: 256,
              attribution: '© OpenStreetMap contributors'
            }
          },
          layers: [
            { id: 'background', type: 'background', paint: { 'background-color': '#f8f9fa' } },
            { id: 'simple-tiles-layer', type: 'raster', source: 'simple-tiles', paint: { 'raster-opacity': 0.9 } }
          ]
        },
        center: [0, 20],
        zoom: 1.5,
        projection: 'mercator'
      })

      this.map = map
      window.map = map
    } catch (error) {
      console.error('Error initializing map:', error)
      return
    }

    map.on('load', () => {
      // Add timezone overlay with hover highlight
      this.addTimezoneOverlay(map)
      // Add day/night sunlight overlay
      this.addSunlightOverlay(map)
      // Add simple controls
      map.addControl(new maplibregl.NavigationControl(), 'bottom-right')
      map.addControl(new maplibregl.ScaleControl({ maxWidth: 100, unit: 'metric' }), 'bottom-left')

      // Add team member markers
      users.forEach(user => {
        const markerEl = document.createElement('div')
        markerEl.className = 'team-marker-pin'
        markerEl.setAttribute('data-user-id', user.id)
        markerEl.innerHTML = `
          <div class="relative flex flex-col items-center">
            <div class="relative">
              <img src="${user.profile_picture}" alt="${user.name}" class="w-12 h-12 rounded-full border-3 border-white shadow-lg object-cover cursor-pointer" />
            </div>
          </div>
        `

        new maplibregl.Marker({ element: markerEl, anchor: 'bottom' })
          .setLngLat([user.longitude, user.latitude])
          .addTo(map)

        // Delegate UI to LiveView: open profile modal
        markerEl.addEventListener('click', (e) => {
          e.stopPropagation()
          this.pushEvent('show_profile', { user_id: user.id })
        })
      })
    })
  },

  async addTimezoneOverlay(map) {
    try {
      const url = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_time_zones.geojson'
      const response = await fetch(`${url}?t=${Date.now()}`, { cache: 'no-cache' })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()

      if (!data || !Array.isArray(data.features)) return

      // Normalize properties and add a stable uid for filtering
      data.features.forEach((f, i) => {
        const p = f.properties || {}
        const tzid = p.tzid || p.TZID || p.timezone || p.time_zone || p.zone || p.ZONE || p.NAME || p.name || `tz_${i}`
        f.properties = { ...p, tzid, __uid: i }
      })

      // Source
      if (map.getSource('timezones')) map.removeSource('timezones')
      map.addSource('timezones', { type: 'geojson', data })

      // Base fill layer (light)
      if (map.getLayer('tz-fill')) map.removeLayer('tz-fill')
      map.addLayer({
        id: 'tz-fill',
        type: 'fill',
        source: 'timezones',
        paint: { 'fill-color': '#3b82f6', 'fill-opacity': 0.05 }
      })

      // Hover layer (highlighted)
      if (map.getLayer('tz-hover')) map.removeLayer('tz-hover')
      map.addLayer({
        id: 'tz-hover',
        type: 'fill',
        source: 'timezones',
        paint: { 'fill-color': '#3b82f6', 'fill-opacity': 0.3 },
        layout: { visibility: 'none' }
      })

      // Border layer
      if (map.getLayer('tz-border')) map.removeLayer('tz-border')
      map.addLayer({
        id: 'tz-border',
        type: 'line',
        source: 'timezones',
        paint: { 'line-color': '#2563eb', 'line-width': 0.6, 'line-opacity': 0.35 }
      })

      // Interactions
      map.on('mousemove', 'tz-fill', (e) => {
        map.getCanvas().style.cursor = 'pointer'
        const f = e.features && e.features[0]
        if (!f) return
        const uid = f.properties && f.properties.__uid
        try {
          map.setFilter('tz-hover', ['==', ['get', '__uid'], uid])
          map.setLayoutProperty('tz-hover', 'visibility', 'visible')
        } catch (_) {}
      })

      map.on('mouseleave', 'tz-fill', () => {
        map.getCanvas().style.cursor = ''
        try { map.setLayoutProperty('tz-hover', 'visibility', 'none') } catch (_) {}
      })

      // Click popup with timezone info
      map.on('click', 'tz-fill', (e) => {
        const f = e.features && e.features[0]
        if (!f) return
        const props = f.properties || {}
        const tzid = props.tzid || props.timezone || props.time_zone || props.zone || props.ZONE || props.NAME || props.name || 'UTC'
        const name = props.NAME || props.name || tzid

        let currentTime = 'N/A'
        try {
          currentTime = new Date().toLocaleString(undefined, { timeZone: tzid, hour: '2-digit', minute: '2-digit' })
        } catch (_) {}

        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="p-3">
              <div class="font-semibold text-gray-900">${name}</div>
              <div class="text-xs text-gray-500 mt-1">${tzid}</div>
              <div class="text-xs text-gray-700 mt-1">Current time: ${currentTime}</div>
            </div>
          `)
          .addTo(map)
      })
    } catch (err) {
      console.warn('Failed to load timezone overlay:', err)
    }
  },

  // --- Day/Night Sunlight Overlay ---
  addSunlightOverlay(map) {
    // Initial draw
    const now = new Date()
    const solar = this.calculateSolarPosition(now)
    const terminator = this.buildTerminator(solar)
    const nightPolygon = this.createNightPolygon(terminator, now)

    if (map.getSource('night-overlay')) map.removeSource('night-overlay')
    map.addSource('night-overlay', {
      type: 'geojson',
      data: {
        type: 'Feature',
        geometry: { type: 'Polygon', coordinates: [nightPolygon] },
        properties: { type: 'night' }
      }
    })

    if (map.getLayer('night-overlay')) map.removeLayer('night-overlay')
    map.addLayer({
      id: 'night-overlay',
      type: 'fill',
      source: 'night-overlay',
      paint: { 'fill-color': '#000000', 'fill-opacity': 0.15 }
    })

    // Update every minute
    if (this.sunlightInterval) clearInterval(this.sunlightInterval)
    this.sunlightInterval = setInterval(() => this.updateSunlightOverlay(map), 60_000)
  },

  updateSunlightOverlay(map) {
    const now = new Date()
    const solar = this.calculateSolarPosition(now)
    const terminator = this.buildTerminator(solar)
    const nightPolygon = this.createNightPolygon(terminator, now)

    const src = map.getSource('night-overlay')
    if (!src) return
    src.setData({
      type: 'Feature',
      geometry: { type: 'Polygon', coordinates: [nightPolygon] },
      properties: { type: 'night' }
    })
  },

  // Build the day/night terminator line (lon sweep, derive lat)
  buildTerminator(solar) {
    const points = []
    for (let lon = -180; lon <= 180; lon += 1) {
      const lat = this.calculateTerminatorLatitude(lon, solar)
      if (!Number.isNaN(lat) && lat >= -90 && lat <= 90) points.push([lon, lat])
    }
    return points
  },

  // NOAA-inspired solar position approximation (sufficient for overlay)
  calculateSolarPosition(date) {
    const julianDay = this.getJulianDay(date)
    const T = (julianDay - 2451545.0) / 36525.0
    const L0 = this.mod(280.46646 + T * (36000.76983 + T * 0.0003032), 360)
    const M = 357.52911 + T * (35999.05029 - 0.0001537 * T)
    const e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T)
    const C = Math.sin(this.deg2rad(M)) * (1.914602 - T * (0.004817 + 0.000014 * T))
            + Math.sin(this.deg2rad(2 * M)) * (0.019993 - 0.000101 * T)
            + Math.sin(this.deg2rad(3 * M)) * 0.000289
    const trueLong = L0 + C
    const meanObliq = 23 + (26 + ((21.448 - T * (46.815 + T * (0.00059 - T * 0.001813)))) / 60) / 60
    const obliqCorr = meanObliq + 0.00256 * Math.cos(this.deg2rad(125.04 - 1934.136 * T))
    const decl = this.rad2deg(Math.asin(Math.sin(this.deg2rad(obliqCorr)) * Math.sin(this.deg2rad(trueLong))))
    const varY = Math.tan(this.deg2rad(obliqCorr / 2)) ** 2
    const eqTime = 4 * this.rad2deg(varY * Math.sin(2 * this.deg2rad(L0))
      - 2 * e * Math.sin(this.deg2rad(M))
      + 4 * e * varY * Math.sin(this.deg2rad(M)) * Math.cos(2 * this.deg2rad(L0))
      - 0.5 * varY * varY * Math.sin(4 * this.deg2rad(L0))
      - 1.25 * e * e * Math.sin(2 * this.deg2rad(M)))
    return { declination: decl, equationOfTime: eqTime }
  },

  // Latitude where sun is on the horizon for given longitude
  calculateTerminatorLatitude(longitude, solar) {
    const { declination, equationOfTime } = solar
    const timeCorr = equationOfTime + 4 * longitude
    const now = new Date()
    const minutes = now.getUTCHours() * 60 + now.getUTCMinutes() + now.getUTCSeconds() / 60
    const localSolarTime = minutes + timeCorr
    const hourAngle = (localSolarTime / 4) - 180
    const declRad = this.deg2rad(declination)
    const hRad = this.deg2rad(hourAngle)
    if (Math.abs(Math.cos(hRad)) < 1e-6) {
      return declination > 0 ? 90 - Math.abs(declination) : -90 + Math.abs(declination)
    }
    const latRad = Math.atan(-Math.cos(hRad) / Math.tan(declRad))
    return this.rad2deg(latRad)
  },

  // Close the polygon to the night side
  createNightPolygon(terminatorPoints, now) {
    const noonUTC = new Date(now)
    noonUTC.setUTCHours(12, 0, 0, 0)
    const isAfterNoon = now.getTime() >= noonUTC.getTime()

    const nightSide = []
    if (isAfterNoon) {
      nightSide.push([-180, 85])
      terminatorPoints.forEach(p => nightSide.push(p))
      nightSide.push([180, 85], [180, -85], [-180, -85], [-180, 85])
    } else {
      nightSide.push([180, 85])
      terminatorPoints.slice().reverse().forEach(p => nightSide.push(p))
      nightSide.push([-180, 85], [-180, -85], [180, -85], [180, 85])
    }
    return nightSide
  },

  // Math helpers
  getJulianDay(date) {
    const a = Math.floor((14 - (date.getUTCMonth() + 1)) / 12)
    const y = date.getUTCFullYear() + 4800 - a
    const m = (date.getUTCMonth() + 1) + 12 * a - 3
    const jdn = date.getUTCDate() + Math.floor((153 * m + 2) / 5) + 365 * y + Math.floor(y / 4) - Math.floor(y / 100) + Math.floor(y / 400) - 32045
    const timeOfDay = (date.getUTCHours() + date.getUTCMinutes() / 60 + date.getUTCSeconds() / 3600) / 24
    return jdn + timeOfDay - 0.5
  },
  deg2rad(d) { return d * Math.PI / 180 },
  rad2deg(r) { return r * 180 / Math.PI },
  mod(a, b) { return ((a % b) + b) % b },

  destroyed() {
    if (this.sunlightInterval) clearInterval(this.sunlightInterval)
  }
}

export default TeamMap


