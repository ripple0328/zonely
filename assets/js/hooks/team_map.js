// TeamMap hook (simplified) for MapLibre GL JS integration
// Focused on LiveView-driven UI: clicking markers triggers server-side modal

const TeamMap = {
  mounted() {
    // Store initial timezone info - will calculate offset properly after map loads
    try {
      this.viewerTz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Etc/UTC'
    } catch (_e) {
      this.viewerTz = 'Etc/UTC'
    }

    // Ensure custom popup styles are present
    this.ensurePopupStyles()

    const users = JSON.parse(this.el.dataset.users || '[]')
    window.teamUsers = users
    this.markersById = {}
    this.selectedMarkerEl = null

    this.handleEvent('focus_user', ({ user_id }) => {
      const marker = this.markersById && this.markersById[user_id]
      if (!marker || !this.map) return

      if (this.selectedMarkerEl) this.selectedMarkerEl.classList.remove('is-selected')
      const markerEl = marker.getElement()
      markerEl.classList.add('is-selected')
      markerEl.dataset.selected = 'true'
      this.selectedMarkerEl = markerEl

      this.map.flyTo({
        center: marker.getLngLat(),
        zoom: Math.max(this.map.getZoom(), 3.4),
        speed: 0.85,
        curve: 1.25,
        essential: true
      })
    })

    this.handleEvent('team_marker_states', (payload) => {
      this.applyMarkerStates(payload)
    })

    if (!window.maplibregl) {
      this.el.dataset.mapState = 'missing-maplibre'
      return
    }

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
            { id: 'background', type: 'background', paint: { 'background-color': '#eef2ef' } },
            { id: 'simple-tiles-layer', type: 'raster', source: 'simple-tiles', paint: { 'raster-opacity': 0.78, 'raster-saturation': -0.45, 'raster-contrast': -0.08 } }
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
      // Now that all methods are available, properly calculate viewer offset
      this.viewerOffsetHours = this.resolveOffsetHours(this.viewerTz, {})
      
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
        const status = ['working', 'edge', 'off'].includes(user.status) ? user.status : 'off'
        markerEl.className = `team-marker-pin state-${status}`
        markerEl.setAttribute('data-user-id', user.id)
        markerEl.setAttribute('data-status', status)
        markerEl.dataset.selected = user.selected ? 'true' : 'false'
        if (user.selected) {
          markerEl.classList.add('is-selected')
          this.selectedMarkerEl = markerEl
        }
        const picture = this.escapeHtml(user.profile_picture || '')
        const name = this.escapeHtml(user.name || 'Team member')
        markerEl.innerHTML = `
          <div class="relative flex flex-col items-center">
            <div class="relative">
              <span class="marker-pulse" aria-hidden="true"></span>
              <img src="${picture}" alt="${name}" class="h-12 w-12 rounded-full border-[3px] border-white object-cover shadow-lg cursor-pointer" />
            </div>
          </div>
        `

        const marker = new maplibregl.Marker({ element: markerEl, anchor: 'bottom' })
          .setLngLat([user.longitude, user.latitude])
          .addTo(map)

        this.markersById[user.id] = marker

        // Delegate UI to LiveView: open profile modal
        markerEl.addEventListener('click', (e) => {
          e.stopPropagation()
          this.pushEvent('show_profile', { user_id: user.id })
        })
      })
    })
  },

  escapeHtml(value) {
    return String(value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;')
  },

  applyMarkerStates(payload) {
    const markers = Array.isArray(payload && payload.markers) ? payload.markers : []
    const selectedUserId = payload && payload.selected_user_id != null ? String(payload.selected_user_id) : null

    markers.forEach(markerState => {
      if (!markerState || markerState.id == null) return

      const userId = String(markerState.id)
      const marker = this.markersById && this.markersById[userId]
      if (!marker) return

      const markerEl = marker.getElement()
      const status = ['working', 'edge', 'off'].includes(markerState.status) ? markerState.status : 'off'
      const isSelected = selectedUserId ? userId === selectedUserId : markerState.selected === true

      markerEl.classList.remove('state-working', 'state-edge', 'state-off')
      markerEl.classList.add(`state-${status}`)
      markerEl.classList.toggle('is-selected', isSelected)
      markerEl.dataset.status = status
      markerEl.dataset.effectiveAt = payload.effective_at || ''
      markerEl.dataset.previewMode = payload.mode || 'live'
      markerEl.dataset.selected = isSelected ? 'true' : 'false'

      if (isSelected) this.selectedMarkerEl = markerEl
    })

    if (!selectedUserId && this.selectedMarkerEl) {
      this.selectedMarkerEl.classList.remove('is-selected')
      this.selectedMarkerEl.dataset.selected = 'false'
      this.selectedMarkerEl = null
    }

    if (window.teamUsers) {
      const stateById = new Map(markers.map(markerState => [String(markerState.id), markerState]))
      window.teamUsers = window.teamUsers.map(user => {
        const markerState = stateById.get(String(user.id))
        if (!markerState) return user

        return {
          ...user,
          status: markerState.status,
          selected: selectedUserId ? String(user.id) === selectedUserId : markerState.selected === true
        }
      })
    }
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
        paint: { 'fill-color': '#1f8a70', 'fill-opacity': 0.045 }
      })

      // Hover layer (highlighted)
      if (map.getLayer('tz-hover')) map.removeLayer('tz-hover')
      map.addLayer({
        id: 'tz-hover',
        type: 'fill',
        source: 'timezones',
        paint: { 'fill-color': '#1f8a70', 'fill-opacity': 0.18 },
        layout: { visibility: 'none' }
      })

      // Border layer
      if (map.getLayer('tz-border')) map.removeLayer('tz-border')
      map.addLayer({
        id: 'tz-border',
        type: 'line',
        source: 'timezones',
        paint: { 'line-color': '#1f8a70', 'line-width': 0.6, 'line-opacity': 0.24 }
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

      // Click popup with timezone info (restore previous design)
      map.on('click', 'tz-fill', (e) => {
        const f = e.features && e.features[0]
        if (!f) return
        const props = f.properties || {}
        const tzid = props.tzid || props.timezone || props.time_zone || props.zone || props.ZONE || props.NAME || props.name || 'UTC'

        const offsetHours = this.resolveOffsetHours(tzid, props)
        const baseName = props.NAME || props.name || tzid.split('/').slice(-1)[0].replace(/_/g, ' ')
        const displayName = baseName && baseName.length > 1 ? baseName : this.friendlyZoneName(tzid, offsetHours)
        const { timeStr, dateStr } = this.formatTimeAndDate(tzid, offsetHours)
        const rel = this.relativeToViewer(offsetHours, tzid)
        const weekend = this.isWeekendInZone(tzid, offsetHours)
        const isDay = this.isDaytimeInZone(tzid, offsetHours)

        const theme = isDay ? 'tzp-light' : 'tzp-dark'
        // Determine best anchor position based on click location
        const mapContainer = map.getContainer()
        const containerRect = mapContainer.getBoundingClientRect()
        const clickPoint = map.project(e.lngLat)
        
        let anchor = 'bottom'
        if (clickPoint.x < containerRect.width * 0.3) {
          anchor = 'bottom-left'
        } else if (clickPoint.x > containerRect.width * 0.7) {
          anchor = 'bottom-right'
        }
        
        if (clickPoint.y < containerRect.height * 0.3) {
          anchor = anchor.replace('bottom', 'top')
        }

        const popup = new maplibregl.Popup({ 
          className: 'tz-popup', 
          closeButton: false, 
          closeOnMove: true, 
          offset: 18,
          maxWidth: '320px',
          anchor: anchor
        })
          .setLngLat(e.lngLat)
          .setHTML(this.renderPopup({ theme, displayName, timeStr, dateStr, rel, weekend }))
          .addTo(map)

        try {
          const el = popup.getElement()
          const btn = el && el.querySelector('.tzp-close')
          if (btn) btn.onclick = () => popup.remove()
        } catch (_) {}
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
      paint: { 'fill-color': '#0f172a', 'fill-opacity': 0.38 }
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
    // Determine which side is night based on solar position
    const utcHours = now.getUTCHours() + now.getUTCMinutes() / 60
    // Sun subsolar longitude: (12 - utcHours) * 15 degrees
    const sunLongitude = (12 - utcHours) * 15

    // The night side is opposite to where the sun is
    // When sun is west (negative), night should be EAST
    // When sun is east (positive), night should be WEST
    const nightIsEast = sunLongitude < 0

    // Terminator points go from lon=-180 to lon=+180
    // We need to create a closed polygon that fills one hemisphere
    const nightSide = []

    // Get the terminator endpoints
    const firstT = terminatorPoints[0]  // at lon=-180
    const lastT = terminatorPoints[terminatorPoints.length - 1]  // at lon=+180

    if (nightIsEast) {
      // Shade the EAST side (when sun is in WEST)
      // Follow terminator from west to east
      terminatorPoints.forEach(p => nightSide.push(p))
      // Go up the right edge to top-right corner
      nightSide.push([180, 85])
      // Go across the top to top-left corner
      nightSide.push([-180, 85])
      // Close back to terminator start (polygon auto-closes)
    } else {
      // Shade the WEST side (when sun is in EAST)
      // Follow terminator from west to east
      terminatorPoints.forEach(p => nightSide.push(p))
      // Go down the right edge to bottom-right corner
      nightSide.push([180, -85])
      // Go across the bottom to bottom-left corner
      nightSide.push([-180, -85])
      // Close back to terminator start (polygon auto-closes)
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

  // Timezone popup helpers
  parseOffsetHours(props, tzid) {
    const candidates = [
      props.utc_offset, props.UTC_OFFSET,
      props.offset, props.OFFSET,
      props.gmt_offset, props.GMT_OFFSET,
      typeof tzid === 'string' ? tzid : null
    ].filter(Boolean)

    for (const val of candidates) {
      // Match formats like "+01:00", "-5", "+5.5", "UTC+01:00", "GMT-3"
      const m = String(val).match(/([+-]?)(\d{1,2})(?::?(\d{2}))?/) || []
      if (m.length >= 3) {
        const sign = m[1] === '-' ? -1 : 1
        const h = parseInt(m[2], 10)
        const mm = m[3] ? parseInt(m[3], 10) : 0
        if (!Number.isNaN(h) && !Number.isNaN(mm)) return sign * (h + mm / 60)
      }
    }
    return null
  },

  offsetLabel(hours) {
    if (hours == null) return 'UTC'
    const sign = hours >= 0 ? '+' : '-'
    const abs = Math.abs(hours)
    const whole = Math.floor(abs)
    const mins = Math.round((abs - whole) * 60)
    return mins === 0 ? `${sign}${whole}` : `${sign}${whole}${mins === 30 ? '.5' : ''}`
  },

  formatUtcOffset(hours) {
    if (hours == null) return 'UTC'
    const sign = hours >= 0 ? '+' : '-'
    const abs = Math.abs(hours)
    const whole = Math.floor(abs)
    const mins = Math.round((abs - whole) * 60)
    const hh = String(whole).padStart(2, '0')
    const mm = String(mins).padStart(2, '0')
    return `UTC${sign}${hh}:${mm}`
  },

  formatTimeFromOffset(hours) {
    try {
      const now = new Date()
      const utcMinutes = now.getUTCHours() * 60 + now.getUTCMinutes()
      const localMinutes = utcMinutes + Math.round(hours * 60)
      const hh = Math.floor(((localMinutes % 1440) + 1440) % 1440 / 60)
      const mm = ((localMinutes % 60) + 60) % 60
      return `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`
    } catch (_e) {
      return 'N/A'
    }
  },

  // Presentational helpers to match previous popup styling/content
  resolveOffsetHours(tzid, props) {
    // Handle UTC±XX:XX format - use literal offset values
    if (typeof tzid === 'string' && tzid.match(/^UTC[+-]\d{2}:\d{2}$/)) {
      const m = tzid.match(/^UTC([+-])(\d{2}):(\d{2})$/)
      if (m) {
        const sign = m[1] === '-' ? -1 : 1
        const standardOffset = sign * (parseInt(m[2], 10) + parseInt(m[3], 10) / 60)
        return standardOffset
      }
    }
    
    // Try IANA with formatToParts to get offset; fallback to parsing
    try {
      const fmt = new Intl.DateTimeFormat('en-US', { timeZone: tzid, timeZoneName: 'shortOffset' })
      const parts = fmt.formatToParts(new Date())
      const tzPart = parts.find(p => p.type === 'timeZoneName')
      if (tzPart && tzPart.value) {
        const m = tzPart.value.match(/GMT([+-]\d{1,2})(?::(\d{2}))?/)
        if (m) {
          const h = parseInt(m[1], 10)
          const mm = m[2] ? parseInt(m[2], 10) : 0
          return h + (h >= 0 ? mm : -mm) / 60
        }
      }
    } catch (_) {}
    return this.parseOffsetHours(props, tzid)
  },

  formatDateTimeYMDHM(tzid, offsetHours) {
    try {
      const d = new Date()
      const ymd = new Intl.DateTimeFormat('en-CA', { timeZone: tzid, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d).replaceAll('-', '/')
      const hm = new Intl.DateTimeFormat('en-US', { timeZone: tzid, hour: '2-digit', minute: '2-digit', hour12: false }).format(d)
      return `${ymd}-${hm}`
    } catch (_) {
      if (offsetHours != null) {
        const d = new Date()
        const yyyy = d.getUTCFullYear()
        const mm = String(d.getUTCMonth() + 1).padStart(2, '0')
        const dd = String(d.getUTCDate()).padStart(2, '0')
        const hm = this.formatTimeFromOffset(offsetHours)
        return `${yyyy}/${mm}/${dd}-${hm}`
      }
      return 'N/A'
    }
  },

  formatTimeAndDate(tzid, offsetHours) {
    try {
      const d = new Date()
      const timeStr = new Intl.DateTimeFormat('en-US', { timeZone: tzid, hour: '2-digit', minute: '2-digit', hour12: false }).format(d)
      const dateStr = new Intl.DateTimeFormat('en-CA', { timeZone: tzid, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d).replaceAll('-', '/')
      return { timeStr, dateStr }
    } catch (_) {
      const timeStr = offsetHours != null ? this.formatTimeFromOffset(offsetHours) : 'N/A'
      const d = new Date()
      const dateStr = `${d.getUTCFullYear()}/${String(d.getUTCMonth() + 1).padStart(2, '0')}/${String(d.getUTCDate()).padStart(2, '0')}`
      return { timeStr, dateStr }
    }
  },

  relativeToViewer(zoneOffset, clickedTzid) {
    // Always get the current actual offset for both viewer and clicked timezone
    const currentClickedOffset = this.getCurrentActualOffset(clickedTzid, zoneOffset)
    const currentViewerOffset = this.getCurrentActualOffset(this.viewerTz, this.viewerOffsetHours)
    
    if (currentClickedOffset == null || currentViewerOffset == null) return ''
    
    const diff = Math.round((currentClickedOffset - currentViewerOffset) * 10) / 10
    if (diff === 0) return 'same time as you'
    
    const abs = Math.abs(diff)
    const units = abs === Math.floor(abs) ? `${abs} hours` : `${Math.floor(abs)} hours ${Math.round((abs - Math.floor(abs)) * 60)} min`
    return `${diff > 0 ? '+' : '-'}${units} ${diff > 0 ? 'ahead' : 'behind'} of you`
  },

  getCurrentActualOffset(tzid, fallbackOffset) {
    // For IANA timezone IDs, get the current actual offset (accounts for DST)
    try {
      if (tzid && typeof tzid === 'string' && !tzid.match(/^UTC[+-]/)) {
        const fmt = new Intl.DateTimeFormat('en-US', { timeZone: tzid, timeZoneName: 'shortOffset' })
        const parts = fmt.formatToParts(new Date())
        const tzPart = parts.find(p => p.type === 'timeZoneName')
        if (tzPart && tzPart.value) {
          const m = tzPart.value.match(/GMT([+-]\d{1,2})(?::(\d{2}))?/)
          if (m) {
            const h = parseInt(m[1], 10)
            const mm = m[2] ? parseInt(m[2], 10) : 0
            return h + (h >= 0 ? mm : -mm) / 60
          }
        }
      }
    } catch (_) {}

    // For UTC±XX:XX format, try to map to a representative IANA timezone
    if (typeof tzid === 'string' && tzid.match(/^UTC[+-]\d{2}:\d{2}$/)) {
      const m = tzid.match(/^UTC([+-])(\d{2}):(\d{2})$/)
      if (m) {
        const standardOffset = parseInt(m[1] + m[2], 10)
        
        // Map to representative IANA timezones that follow DST rules
        const offsetToTimezone = {
          '-8': 'America/Los_Angeles',  // Pacific Time
          '-7': 'America/Denver',       // Mountain Time  
          '-6': 'America/Chicago',      // Central Time
          '-5': 'America/New_York',     // Eastern Time
          '-4': 'America/Halifax',      // Atlantic Time
          '0': 'Europe/London',         // GMT/BST
          '1': 'Europe/Berlin',         // CET/CEST
          '2': 'Europe/Athens'          // EET/EEST
        }
        
        const representativeTz = offsetToTimezone[standardOffset.toString()]
        if (representativeTz) {
          return this.getCurrentActualOffset(representativeTz, fallbackOffset)
        }
        
        // For timezones without DST, use literal offset
        return standardOffset
      }
    }
    
    return fallbackOffset
  },


  isWeekendInZone(tzid, offsetHours) {
    try {
      const parts = new Intl.DateTimeFormat('en-US', { timeZone: tzid, weekday: 'short' }).formatToParts(new Date())
      const wk = parts.find(p => p.type === 'weekday')?.value || ''
      return wk === 'Sat' || wk === 'Sun'
    } catch (_) {
      if (offsetHours == null) return false
      const now = new Date()
      const utcDay = now.getUTCDay()
      const localHour = (now.getUTCHours() + offsetHours + 24) % 24
      // Rough approximation: adjust day when crossing midnight
      const dayShift = localHour < 0 ? -1 : localHour >= 24 ? 1 : 0
      const d = (utcDay + dayShift + 7) % 7
      return d === 0 || d === 6
    }
  },

  isDaytimeInZone(tzid, offsetHours) {
    try {
      const hour = parseInt(new Intl.DateTimeFormat('en-US', { timeZone: tzid, hour: '2-digit', hour12: false }).format(new Date()), 10)
      return hour >= 6 && hour < 18
    } catch (_) {
      if (offsetHours == null) return true
      const hour = (new Date().getUTCHours() + offsetHours + 24) % 24
      return hour >= 6 && hour < 18
    }
  },

  // --- Popup rendering & formatting ---
  renderPopup({ theme, displayName, timeStr, dateStr, rel, weekend }) {
    const weekendRow = `<div class="tzp-row tzp-weekend" aria-live="polite"><span class="tzp-dot"></span><span>${weekend ? 'Weekend' : 'Weekday'}</span></div>`
    return `
      <div class="tzp ${theme}" role="dialog" aria-label="Timezone information">
        <button class="tzp-close" aria-label="Close">Close</button>
        <div class="tzp-row tzp-title"><span class="tzp-kicker">Zone</span><span class="tzp-title-text">${displayName}</span></div>
        <div class="tzp-row tzp-datetime"><span class="tzp-kicker">Local</span><span class="tzp-dt">${timeStr}</span><span class="tzp-date">${dateStr}</span></div>
        <div class="tzp-row tzp-relative"><span class="tzp-kicker">Offset</span><span>${rel}</span></div>
        <div class="tzp-divider"></div>
        ${weekendRow}
      </div>
    `
  },

  friendlyZoneName(tzid, offsetHours) {
    const city = tzid && tzid.split('/').slice(-1)[0].replace(/_/g, ' ')
    if (city && city.length > 1) return city
    return `${this.offsetLabel(offsetHours || 0)} time`
  },

  ensurePopupStyles() {
    if (document.getElementById('tz-popup-styles')) return
    const style = document.createElement('style')
    style.id = 'tz-popup-styles'
    style.innerHTML = `
      .maplibregl-popup.tz-popup { max-width: none !important; }
      .maplibregl-popup.tz-popup .maplibregl-popup-content { 
        padding: 0; 
        border-radius: 18px;
        box-shadow: 0 22px 70px rgba(22,26,29,0.16), inset 0 1px 0 rgba(255,255,255,0.42);
        overflow: hidden; 
        border: none; 
        max-width: 320px;
        width: max-content;
      }
      .maplibregl-popup.tz-popup .maplibregl-popup-tip { display: none; }
      .tzp { position: relative; padding: 18px 20px 16px 20px; min-width: 280px; max-width: 320px; }
      .tzp-dark { background: linear-gradient(180deg,#161a1d 0%, #25313a 100%); color: #f7f8f6; border: 1px solid rgba(255,255,255,0.12); }
      .tzp-light { background: rgba(255,255,255,0.92); color: #161a1d; border: 1px solid rgba(22,26,29,0.1); }
      .tzp-row { display: grid; grid-template-columns: 54px 1fr; align-items: center; gap: 10px; }
      .tzp-kicker { color: #5f6b73; font-family: "JetBrains Mono", "Geist Mono", monospace; font-size: 10px; letter-spacing: .12em; text-transform: uppercase; }
      .tzp-dark .tzp-kicker { color: rgba(247,248,246,0.64); }
      .tzp-title { margin-bottom: 8px; }
      .tzp-title-text { font-size: 18px; font-weight: 700; word-break: break-word; }
      .tzp-dark .tzp-title-text { color: #ffffff; }
      .tzp-datetime { margin-bottom: 6px; }
      .tzp-dt { font-family: "JetBrains Mono", "Geist Mono", monospace; font-size: 24px; font-weight: 800; letter-spacing: 0; margin-right: 10px; white-space: nowrap; }
      .tzp-date { font-size: 14px; opacity: .85; white-space: nowrap; }
      .tzp-relative { font-size: 14px; margin-bottom: 8px; }
      .tzp-dark .tzp-divider { height: 1px; background: rgba(255,255,255,0.08); margin: 10px 0; }
      .tzp-light .tzp-divider { height: 1px; background: rgba(22,26,29,0.08); margin: 10px 0; }
      .tzp-weekend { font-size: 14px; }
      .tzp-dark .tzp-dot { width: 10px; height: 10px; border-radius: 9999px; background: #d99a2b; display: inline-block; margin-right: 8px; flex-shrink: 0; }
      .tzp-light .tzp-dot { width: 10px; height: 10px; border-radius: 9999px; background: #1f8a70; display: inline-block; margin-right: 8px; flex-shrink: 0; }
      .tzp-close { position: absolute; top: 10px; right: 10px; min-width: 52px; height: 28px; padding: 0 10px; border-radius: 9999px; border: none; cursor: pointer; line-height: 28px; text-align: center; font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }
      .tzp-dark .tzp-close { background: rgba(255,255,255,0.08); color: #ffffff; }
      .tzp-dark .tzp-close:hover { background: rgba(255,255,255,0.16); }
      .tzp-light .tzp-close { background: rgba(31,138,112,0.10); color: #1f8a70; }
      .tzp-light .tzp-close:hover { background: rgba(31,138,112,0.16); }
      .maplibregl-popup-close-button { display: none; }
    `
    document.head.appendChild(style)
  },

  destroyed() {
    if (this.sunlightInterval) clearInterval(this.sunlightInterval)
  }
}

export default TeamMap
