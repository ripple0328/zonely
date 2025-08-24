// TeamMap hook (simplified) for MapLibre GL JS integration
// Focused on LiveView-driven UI: clicking markers triggers server-side modal

const TeamMap = {
  mounted() {
    console.log('TeamMap hook mounted!')

    // Inform LiveView of the viewer's IANA timezone for correct overlap calculations
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Etc/UTC'
      this.viewerTz = tz
      this.viewerOffsetHours = -new Date().getTimezoneOffset() / 60
      this.pushEvent('set_viewer_tz', { tz })
    } catch (_e) {
      this.viewerTz = 'Etc/UTC'
      this.viewerOffsetHours = 0
      this.pushEvent('set_viewer_tz', { tz: 'Etc/UTC' })
    }

    // Ensure custom popup styles are present
    this.ensurePopupStyles()

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

      // Click popup with timezone info (restore previous design)
      map.on('click', 'tz-fill', (e) => {
        const f = e.features && e.features[0]
        if (!f) return
        const props = f.properties || {}
        const tzid = props.tzid || props.timezone || props.time_zone || props.zone || props.ZONE || props.NAME || props.name || 'UTC'

        const offsetHours = this.resolveOffsetHours(tzid, props)
        const baseName = props.NAME || props.name || tzid.split('/').slice(-1)[0].replace(/_/g, ' ')
        const displayName = baseName && baseName.length > 1 ? baseName : this.friendlyZoneName(tzid, offsetHours)
        const flag = this.flagFromProps(props) || this.flagFromTzid(tzid)
        const { timeStr, dateStr } = this.formatTimeAndDate(tzid, offsetHours)
        const rel = this.relativeToViewer(offsetHours)
        const weekend = this.isWeekendInZone(tzid, offsetHours)
        const isDay = this.isDaytimeInZone(tzid, offsetHours)

        const theme = isDay ? 'tzp-light' : 'tzp-dark'
        const popup = new maplibregl.Popup({ className: 'tz-popup', closeButton: false, closeOnMove: true, offset: 18 })
          .setLngLat(e.lngLat)
          .setHTML(this.renderPopup({ theme, flag, displayName, timeStr, dateStr, rel, weekend }))
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
      paint: { 'fill-color': '#000000', 'fill-opacity': 0.35 }
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
    // Try IANA with formatToParts to get offset; fallback to parsing
    try {
      const fmt = new Intl.DateTimeFormat('en-US', { timeZone: tzid, timeZoneName: 'shortOffset' })
      const parts = fmt.formatToParts(new Date())
      const tzPart = parts.find(p => p.type === 'timeZoneName')
      if (tzPart && tzPart.value) {
        const m = tzPart.value.match(/GMT([+-]\d{1,2})(?::(\d{2}))?/)
        if (m) {
          const sign = m[1].startsWith('-') ? -1 : 1
          const h = parseInt(m[1].replace('+', ''), 10)
          const mm = m[2] ? parseInt(m[2], 10) : 0
          return sign * (h + mm / 60)
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

  relativeToViewer(zoneOffset) {
    if (zoneOffset == null || this.viewerOffsetHours == null) return ''
    const diff = Math.round((zoneOffset - this.viewerOffsetHours) * 10) / 10
    if (diff === 0) return 'same time as you'
    const abs = Math.abs(diff)
    const units = abs === Math.floor(abs) ? `${abs} hours` : `${Math.floor(abs)} hours ${Math.round((abs - Math.floor(abs)) * 60)} min`
    return `${diff > 0 ? '+' : '-'}${units} ${diff > 0 ? 'ahead' : 'behind'} of you`
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

  flagFromProps(props) {
    const cc = props.ISO_A2 || props.iso_a2 || props.ADMIN || props.admin || ''
    if (typeof cc === 'string' && cc.length === 2) return this.flagEmoji(cc)
    return ''
  },

  flagFromTzid(tzid) {
    const cc = tzid && tzid.split('/')?.[0]
    return ''
  },

  flagEmoji(countryCode) {
    try {
      const code = countryCode.trim().toUpperCase()
      return code.replace(/./g, c => String.fromCodePoint(127397 + c.charCodeAt(0)))
    } catch (_) { return '' }
  },

  // --- Popup rendering & formatting ---
  renderPopup({ theme, flag, displayName, timeStr, dateStr, rel, weekend }) {
    const weekendRow = `<div class="tzp-row tzp-weekend" aria-live="polite"><span class="tzp-dot"></span><span>${weekend ? 'Weekend' : 'Weekday'}</span></div>`
    return `
      <div class="tzp ${theme}" role="dialog" aria-label="Timezone information">
        <button class="tzp-close" aria-label="Close">×</button>
        <div class="tzp-row tzp-title"><span class="tzp-icon">📍</span><span class="tzp-title-text">${flag ? flag + ' ' : ''}${displayName}</span></div>
        <div class="tzp-row tzp-datetime"><span class="tzp-icon">🕰️</span><span class="tzp-dt">${timeStr}</span><span class="tzp-date">${dateStr}</span></div>
        <div class="tzp-row tzp-relative"><span class="tzp-icon">⏳</span><span>${rel}</span></div>
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
      .maplibregl-popup.tz-popup .maplibregl-popup-content { padding: 0; border-radius: 16px; box-shadow: 0 18px 36px rgba(0,0,0,0.3); overflow: hidden; border: none; }
      .tzp { position: relative; padding: 18px 20px 16px 20px; min-width: 280px; }
      .tzp-dark { background: linear-gradient(180deg,#0f172a 0%, #0b1222 100%); color: #eaeefb; border: 1px solid rgba(255,255,255,0.1); }
      .tzp-light { background: #ffffff; color: #0f172a; border: 1px solid rgba(0,0,0,0.08); }
      .tzp-row { display: flex; align-items: center; gap: 10px; }
      .tzp-icon { width: 22px; display: inline-block; text-align: center; }
      .tzp-title { margin-bottom: 8px; }
      .tzp-title-text { font-size: 18px; font-weight: 700; }
      .tzp-dark .tzp-title-text { color: #f8e08e; }
      .tzp-datetime { margin-bottom: 6px; }
      .tzp-dt { font-size: 26px; font-weight: 800; letter-spacing: .2px; margin-right: 10px; }
      .tzp-date { font-size: 14px; opacity: .85; }
      .tzp-relative { font-size: 16px; margin-bottom: 8px; }
      .tzp-dark .tzp-divider { height: 1px; background: rgba(255,255,255,0.08); margin: 10px 0; }
      .tzp-light .tzp-divider { height: 1px; background: rgba(0,0,0,0.08); margin: 10px 0; }
      .tzp-weekend { font-size: 16px; }
      .tzp-dark .tzp-dot { width: 12px; height: 12px; border-radius: 9999px; background: #3b82f6; display: inline-block; margin-right: 8px; }
      .tzp-light .tzp-dot { width: 12px; height: 12px; border-radius: 9999px; background: #3b82f6; display: inline-block; margin-right: 8px; }
      .tzp-close { position: absolute; top: 10px; right: 10px; width: 32px; height: 32px; border-radius: 9999px; border: none; cursor: pointer; line-height: 32px; text-align: center; font-size: 18px; }
      .tzp-dark .tzp-close { background: rgba(255,255,255,0.08); color: #f6d26b; }
      .tzp-dark .tzp-close:hover { background: rgba(255,255,255,0.16); }
      .tzp-light .tzp-close { background: rgba(15,23,42,0.06); color: #111827; }
      .tzp-light .tzp-close:hover { background: rgba(15,23,42,0.12); }
      .maplibregl-popup-close-button { display: none; }
    `
    document.head.appendChild(style)
  },

  destroyed() {
    if (this.sunlightInterval) clearInterval(this.sunlightInterval)
  }
}

export default TeamMap


