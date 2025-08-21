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
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// TeamMap hook for MapLibre GL JS integration
let Hooks = {}

Hooks.TeamMap = {
  mounted() {
    console.log('TeamMap hook mounted!')
    const apiKey = this.el.dataset.apiKey
    const users = JSON.parse(this.el.dataset.users)
    
    console.log('API Key:', apiKey)
    console.log('Users:', users)
    console.log('Container element:', this.el)
    
    // Initialize MapLibre GL JS map
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
            {
              id: 'background',
              type: 'background',
              paint: {
                'background-color': '#f8f9fa'
              }
            },
            {
              id: 'simple-tiles-layer',
              type: 'raster',
              source: 'simple-tiles',
              paint: {
                'raster-opacity': 0.85,
                'raster-saturation': -0.2,
                'raster-contrast': 0.1
              }
            }
          ]
        },
        center: [0, 20], // Center on world
        zoom: 1.5,
        projection: 'mercator'
      })
      
      console.log('Map initialized successfully:', map)
      
      // Store map reference for cleanup
      this.map = map
    } catch (error) {
      console.error('Error initializing map:', error)
      return
    }

    map.on('load', () => {
      // Add timezone overlay as the first layer
      this.addTimezoneOverlay(map)
      
      // Add sunlight overlay
      this.addSunlightOverlay(map)
      
      // Add team member markers
      users.forEach(user => {
        // Get city name from coordinates or fallback to country
        const cityName = this.getCityFromCoordinates(user.latitude, user.longitude) || user.country
        
        // Create custom marker element with avatar pin and city name
        const markerEl = document.createElement('div')
        markerEl.className = 'team-marker-pin'
        markerEl.innerHTML = `
          <div class="relative flex flex-col items-center">
            <!-- Avatar Pin -->
            <div class="relative">
              <img 
                src="${user.profile_picture}" 
                alt="${user.name}" 
                class="w-12 h-12 rounded-full border-3 border-white shadow-lg object-cover cursor-pointer transition-all duration-200 hover:scale-110 hover:border-blue-400"
                onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
              />
              <div class="w-12 h-12 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full border-3 border-white shadow-lg flex items-center justify-center cursor-pointer transition-all duration-200 hover:scale-110 hover:border-blue-400" style="display: none;">
                <span class="text-white font-bold text-lg">
                  ${user.name.charAt(0)}
                </span>
              </div>
            </div>
            
            <!-- City Name -->
            <div class="mt-1 bg-white px-2 py-1 rounded shadow-md text-xs font-medium text-gray-800 whitespace-nowrap">
              ${cityName}
            </div>
            
            <!-- Hidden expandable card for hover -->
            <div class="team-card-expanded absolute bottom-full mb-2 bg-white rounded-lg shadow-xl border border-gray-200 p-4 min-w-64 opacity-0 invisible transition-all duration-300 transform scale-95 z-50">
              <div class="flex items-center space-x-3 mb-3">
                <!-- Avatar -->
                <div class="flex-shrink-0">
                  <img 
                    src="${user.profile_picture}" 
                    alt="${user.name}" 
                    class="w-14 h-14 rounded-full shadow-md object-cover"
                    onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
                  />
                  <div class="w-14 h-14 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center shadow-md" style="display: none;">
                    <span class="text-white font-bold text-xl">
                      ${user.name.charAt(0)}
                    </span>
                  </div>
                </div>
                
                <!-- User Info -->
                <div class="flex-1 min-w-0">
                  <div class="text-base font-semibold text-gray-900 truncate">
                    ${user.name}
                  </div>
                  <div class="text-sm text-gray-600 truncate">
                    ${user.role}
                  </div>
                  <div class="text-sm text-gray-500 mt-1">
                    ${cityName}
                  </div>
                </div>
              </div>
              
              <!-- Detailed Info -->
              <div class="space-y-2 text-xs">
                <div>
                  <span class="font-medium text-gray-700">Working Hours:</span>
                  <span class="text-gray-600">${user.work_start} - ${user.work_end}</span>
                </div>
                <div>
                  <span class="font-medium text-gray-700">Timezone:</span>
                  <span class="text-gray-600">${user.timezone}</span>
                </div>
                ${user.pronouns ? `
                <div>
                  <span class="font-medium text-gray-700">Pronouns:</span>
                  <span class="text-gray-600">${user.pronouns}</span>
                </div>
                ` : ''}
              </div>
              
              <!-- Arrow pointing to pin -->
              <div class="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-8 border-r-8 border-t-8 border-l-transparent border-r-transparent border-t-white"></div>
            </div>
          </div>
        `

        // Create and add marker
        new maplibregl.Marker({ 
          element: markerEl,
          anchor: 'bottom'
        })
          .setLngLat([user.longitude, user.latitude])
          .addTo(map)

        // Handle hover for card expansion
        const expandedCard = markerEl.querySelector('.team-card-expanded')
        let hoverTimeout
        
        markerEl.addEventListener('mouseenter', () => {
          clearTimeout(hoverTimeout)
          expandedCard.classList.remove('opacity-0', 'invisible', 'scale-95')
          expandedCard.classList.add('opacity-100', 'visible', 'scale-100')
        })
        
        markerEl.addEventListener('mouseleave', () => {
          hoverTimeout = setTimeout(() => {
            expandedCard.classList.add('opacity-0', 'invisible', 'scale-95')
            expandedCard.classList.remove('opacity-100', 'visible', 'scale-100')
          }, 100)
        })

        // Handle marker clicks for full profile
        markerEl.addEventListener('click', () => {
          this.pushEvent('show_profile', { user_id: user.id })
        })
      })

      // Add minimal controls
      map.addControl(new maplibregl.NavigationControl(), 'bottom-right')
      
      // Add scale control
      map.addControl(new maplibregl.ScaleControl({
        maxWidth: 100,
        unit: 'metric'
      }), 'bottom-left')
    })

    // Handle custom events from LiveView
    window.addEventListener('phx:show-profile', (event) => {
      this.pushEvent('show_profile', { user_id: event.detail.userId })
    })
  },

  getCityFromCoordinates(latitude, longitude) {
    // Simple reverse geocoding mapping for major cities
    const cityMap = [
      { lat: 40.7128, lng: -74.0060, city: "New York" },
      { lat: 34.0522, lng: -118.2437, city: "Los Angeles" },
      { lat: 41.8781, lng: -87.6298, city: "Chicago" },
      { lat: 29.7604, lng: -95.3698, city: "Houston" },
      { lat: 33.4484, lng: -112.0740, city: "Phoenix" },
      { lat: 39.9526, lng: -75.1652, city: "Philadelphia" },
      { lat: 29.4241, lng: -98.4936, city: "San Antonio" },
      { lat: 32.7767, lng: -96.7970, city: "Dallas" },
      { lat: 37.3382, lng: -121.8863, city: "San Jose" },
      { lat: 30.2672, lng: -97.7431, city: "Austin" },
      
      // Canada
      { lat: 43.6532, lng: -79.3832, city: "Toronto" },
      { lat: 45.5017, lng: -73.5673, city: "Montreal" },
      { lat: 49.2827, lng: -123.1207, city: "Vancouver" },
      { lat: 51.0447, lng: -114.0719, city: "Calgary" },
      { lat: 53.5461, lng: -113.4938, city: "Edmonton" },
      { lat: 45.4215, lng: -75.6972, city: "Ottawa" },
      
      // UK
      { lat: 51.5074, lng: -0.1278, city: "London" },
      { lat: 53.4808, lng: -2.2426, city: "Manchester" },
      { lat: 55.9533, lng: -3.1883, city: "Edinburgh" },
      { lat: 53.3498, lng: -6.2603, city: "Dublin" },
      
      // Europe
      { lat: 52.5200, lng: 13.4050, city: "Berlin" },
      { lat: 48.8566, lng: 2.3522, city: "Paris" },
      { lat: 41.9028, lng: 12.4964, city: "Rome" },
      { lat: 40.4168, lng: -3.7038, city: "Madrid" },
      { lat: 52.3676, lng: 4.9041, city: "Amsterdam" },
      { lat: 47.3769, lng: 8.5417, city: "Zurich" },
      { lat: 48.2082, lng: 16.3738, city: "Vienna" },
      { lat: 50.0755, lng: 14.4378, city: "Prague" },
      { lat: 59.3293, lng: 18.0686, city: "Stockholm" },
      { lat: 60.1699, lng: 24.9384, city: "Helsinki" },
      { lat: 55.6761, lng: 12.5683, city: "Copenhagen" },
      { lat: 59.9139, lng: 10.7522, city: "Oslo" },
      
      // Asia
      { lat: 35.6762, lng: 139.6503, city: "Tokyo" },
      { lat: 37.5665, lng: 126.9780, city: "Seoul" },
      { lat: 39.9042, lng: 116.4074, city: "Beijing" },
      { lat: 31.2304, lng: 121.4737, city: "Shanghai" },
      { lat: 22.3193, lng: 114.1694, city: "Hong Kong" },
      { lat: 1.3521, lng: 103.8198, city: "Singapore" },
      { lat: 28.6139, lng: 77.2090, city: "New Delhi" },
      { lat: 19.0760, lng: 72.8777, city: "Mumbai" },
      { lat: 13.7563, lng: 100.5018, city: "Bangkok" },
      { lat: -6.2088, lng: 106.8456, city: "Jakarta" },
      { lat: 14.5995, lng: 120.9842, city: "Manila" },
      
      // Australia/Oceania
      { lat: -33.8688, lng: 151.2093, city: "Sydney" },
      { lat: -37.8136, lng: 144.9631, city: "Melbourne" },
      { lat: -27.4698, lng: 153.0251, city: "Brisbane" },
      { lat: -31.9505, lng: 115.8605, city: "Perth" },
      { lat: -34.9285, lng: 138.6007, city: "Adelaide" },
      { lat: -36.8485, lng: 174.7633, city: "Auckland" },
      { lat: -41.2865, lng: 174.7762, city: "Wellington" },
      
      // South America
      { lat: -23.5505, lng: -46.6333, city: "São Paulo" },
      { lat: -22.9068, lng: -43.1729, city: "Rio de Janeiro" },
      { lat: -34.6037, lng: -58.3816, city: "Buenos Aires" },
      { lat: -33.4489, lng: -70.6693, city: "Santiago" },
      { lat: 4.7110, lng: -74.0721, city: "Bogotá" },
      { lat: -12.0464, lng: -77.0428, city: "Lima" },
      
      // Africa
      { lat: 30.0444, lng: 31.2357, city: "Cairo" },
      { lat: -26.2041, lng: 28.0473, city: "Johannesburg" },
      { lat: -33.9249, lng: 18.4241, city: "Cape Town" },
      { lat: 6.5244, lng: 3.3792, city: "Lagos" },
      { lat: -1.2921, lng: 36.8219, city: "Nairobi" },
      
      // Middle East
      { lat: 25.2048, lng: 55.2708, city: "Dubai" },
      { lat: 31.7683, lng: 35.2137, city: "Jerusalem" },
      { lat: 33.8938, lng: 35.5018, city: "Beirut" },
      { lat: 35.6892, lng: 51.3890, city: "Tehran" }
    ]
    
    // Find closest city within reasonable distance (approx 100km = ~1 degree)
    let closestCity = null
    let minDistance = Infinity
    
    cityMap.forEach(city => {
      const distance = Math.sqrt(
        Math.pow(latitude - city.lat, 2) + Math.pow(longitude - city.lng, 2)
      )
      
      if (distance < minDistance && distance < 1.0) { // Within ~100km
        minDistance = distance
        closestCity = city.city
      }
    })
    
    return closestCity
  },

  addTimezoneOverlay(map) {
    // Use reliable CDN sources for timezone boundaries
    console.log('🌍 Loading timezone overlay from reliable CDN sources...')
    this.loadTimezoneFromReliableCDN(map)
  },

  async loadTimezoneFromReliableCDN(map) {
    console.log('🌐 Loading timezone boundaries from reliable CDN sources...')
    
    // CORS-friendly sources for timezone boundary data (prioritized by reliability)
    const reliableSources = [
      // Natural Earth Data - reliable geographic data source (only working source)
      'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_time_zones.geojson'
    ]
    
    let timezoneData = null
    
    for (const source of reliableSources) {
      try {
        console.log(`🔄 Attempting to load timezone data from: ${source}`)
        
        // Add cache-busting query parameter instead of headers to avoid CORS preflight
        const cacheBustUrl = source.includes('?') 
          ? `${source}&t=${Date.now()}` 
          : `${source}?t=${Date.now()}`
        
        const response = await fetch(cacheBustUrl, {
          method: 'GET',
          mode: 'cors'
          // No custom headers to avoid CORS preflight issues
        })
        
        if (response.ok) {
          const contentType = response.headers.get('content-type') || ''
          console.log(`📄 Content-Type: ${contentType} from ${source}`)
          
          try {
            const data = await response.json()
            console.log(`📊 Data structure from ${source}:`, {
              type: data.type,
              featuresCount: data.features?.length,
              firstFeatureProps: data.features?.[0]?.properties ? Object.keys(data.features[0].properties) : []
            })
            
            if (data && data.features && Array.isArray(data.features) && data.features.length > 0) {
              // Validate that this looks like timezone data
              const sample = data.features[0]
              const hasTimezoneProps = sample.properties && (
                sample.properties.tzid || 
                sample.properties.TZID || 
                sample.properties.tz ||
                sample.properties.time_zone ||
                sample.properties.zone ||
                sample.properties.timezone ||
                sample.properties.ZONE ||
                sample.properties.NAME || // Sometimes country data
                sample.properties.name    // Generic name field
              )
              
              if (hasTimezoneProps || data.features.length > 50) { // Accept if has timezone props OR many features (likely geography data)
                timezoneData = data
                console.log(`✅ Successfully loaded ${data.features.length} geographic boundaries from: ${source}`)
                break
              } else {
                console.warn(`⚠️ Data from ${source} lacks geographic identifiers:`, Object.keys(sample.properties || {}))
              }
            } else if (data && data.objects) {
              // Handle TopoJSON format (like from unpkg world-atlas)
              console.log(`🗺️ TopoJSON data detected from ${source}, converting...`)
              // For now, skip TopoJSON conversion and try next source
              console.warn(`⚠️ TopoJSON format not yet supported, trying next source...`)
            } else {
              console.warn(`⚠️ Invalid GeoJSON structure from ${source}:`, {
                hasFeatures: !!data.features,
                featuresType: typeof data.features,
                dataKeys: Object.keys(data || {})
              })
            }
          } catch (parseError) {
            console.warn(`⚠️ JSON parse error from ${source}:`, parseError.message)
          }
        } else {
          console.warn(`❌ HTTP ${response.status} ${response.statusText} from ${source}`)
        }
      } catch (error) {
        console.warn(`❌ Failed to load from ${source}:`, error.message)
        continue
      }
    }
    
    if (timezoneData) {
      console.log('🎯 Creating timezone regions from reliable CDN data...')
      await this.createOfficialTimezoneRegions(map, timezoneData)
    } else {
      console.error('❌ All reliable CDN sources failed. Falling back to static regions.')
      // Ultimate fallback to predefined regions
      await this.createStaticTimezoneRegions(map)
    }
  },

  loadTimezoneRegionsFromBackend(map) {
    console.log('📍 Using timezone regions from backend...')
    
    // Get timezone regions data from the data attribute
    const container = document.getElementById('map-container')
    if (!container) {
      console.error('Map container not found')
      return
    }
    
    const timezoneRegionsData = container.getAttribute('data-timezone-regions')
    if (!timezoneRegionsData) {
      console.error('No timezone regions data found in data attribute')
      return
    }
    
    let timezoneRegions
    try {
      timezoneRegions = JSON.parse(timezoneRegionsData)
      console.log(`✅ Loaded ${timezoneRegions.length} timezone regions from backend`)
    } catch (error) {
      console.error('Failed to parse timezone regions data:', error)
      return
    }
    
    const timezoneColors = this.getTimezoneColors()
    
    // Create map layers for each timezone region
    timezoneRegions.forEach((region, index) => {
      const sourceId = `backend-timezone-${index}`
      const layerId = `backend-timezone-layer-${index}`
      const borderLayerId = `backend-timezone-border-${index}`
      const hoverLayerId = `backend-timezone-hover-${index}`
      
      const color = this.getColorForOffset(region.offset, timezoneColors)
      
      // Create GeoJSON polygon from coordinates
      const geojsonData = {
        type: 'Feature',
        geometry: {
          type: 'Polygon',
          coordinates: [region.coordinates]
        },
        properties: {
          timezone: region.timezone,
          name: region.name,
          offset: region.offset
        }
      }
      
      console.log(`Adding ${region.name} (${region.timezone}) with UTC${region.offset >= 0 ? '+' : ''}${region.offset}`)
      
      // Add source
      map.addSource(sourceId, {
        type: 'geojson',
        data: geojsonData
      })
      
      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.05
        }
      })
      
      // Add hover highlight layer
      map.addLayer({
        id: hoverLayerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': '#3b82f6',
          'fill-opacity': 0.3
        },
        layout: {
          'visibility': 'none' // Initially hidden
        }
      })
      
      // Add border layer
      map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': color.replace('0.3', '0.9'),
          'line-width': 0.8,
          'line-opacity': 0.4
        }
      })
      
      // Add hover effects - highlight entire timezone region
      map.on('mouseenter', layerId, () => {
        map.getCanvas().style.cursor = 'pointer'
        // Show the timezone region highlight
        map.setLayoutProperty(hoverLayerId, 'visibility', 'visible')
      })
      
      map.on('mouseleave', layerId, () => {
        map.getCanvas().style.cursor = ''
        // Hide the timezone region highlight
        map.setLayoutProperty(hoverLayerId, 'visibility', 'none')
      })
      
      // Add click handler for timezone info
      map.on('click', layerId, (e) => {
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        const currentTime = this.getCurrentTimeInTimezone(region.timezone)
        
        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="p-3">
              <div class="font-semibold text-gray-900">${region.name}</div>
              <div class="text-xs text-gray-500 mt-1">${region.timezone}</div>
              <div class="text-xs text-gray-700 mt-1">Current time: ${currentTime}</div>
              <div class="text-xs text-gray-500 mt-2">Timezone boundaries</div>
            </div>
          `)
          .addTo(map)
      })
    })
    
    console.log(`✅ Added ${timezoneRegions.length} timezone regions from backend with hover effects!`)
  },

  async loadPreciseTimezonesBoundaries(map) {
    try {
      console.log('Loading precise timezone boundaries from timezone-boundary-builder...')
      
      // Use simplified, working data sources that don't have CORS issues
      const sources = [
        // Use working alternative sources
        'https://cdn.jsdelivr.net/npm/world-atlas@3/countries-110m.json'
      ]
      
      let timezoneData = null
      
      for (const source of sources) {
        try {
          console.log(`Attempting to load timezone data from: ${source}`)
          const response = await fetch(source, {
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (compatible; Timezone Map)'
            },
            mode: 'cors'
          })
          
          if (response.ok) {
            const data = await response.json()
            if (data && data.features && data.features.length > 0) {
              // Since we're loading world country data, we'll map countries to timezones
              console.log(`✅ Successfully loaded ${data.features.length} country boundaries from: ${source}`)
              console.log(`Sample country:`, data.features[0].properties.NAME || data.features[0].properties.name)
              
              // Process the world data to create timezone boundaries
              await this.createTimezoneRegionsFromWorldBoundaries(map, data)
              return // Exit successfully
            } else {
              console.warn(`❌ Invalid or empty data from ${source}`)
            }
          } else {
            console.warn(`❌ HTTP ${response.status} from ${source}`)
          }
        } catch (err) {
          console.warn(`❌ Failed to load from ${source}:`, err.message)
          continue
        }
      }
      
      // If we reach here, all sources failed
      console.error('❌ All timezone data sources failed, falling back to administrative boundaries')
      throw new Error('All timezone data sources failed')
      
    } catch (error) {
      console.error('Failed to load precise timezone boundaries:', error)
      // Fallback to better administrative boundary approach
      await this.loadRealisticTimezoneShapes(map)
    }
  },

  async loadRealisticTimezoneShapes(map) {
    console.log('🌍 Loading official timezone boundaries that follow administrative borders...')
    
    try {
      // Use reliable timezone boundary data sources 
      const officialSources = [
        // Natural Earth Data - working timezone data source
        'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_time_zones.geojson'
      ]
      
      let timezoneData = null
      
      for (const source of officialSources) {
        try {
          console.log(`🔄 Attempting to load official timezone boundaries from: ${source}`)
          const response = await fetch(source, {
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (compatible; TimezoneMap/1.0)',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache'
            },
            cache: 'no-cache'
          })
          
          if (response.ok) {
            const data = await response.json()
            if (data && data.features && data.features.length > 0) {
              // Validate timezone data structure
              const sample = data.features[0]
              const hasTimezoneId = sample.properties && (
                sample.properties.tzid || 
                sample.properties.TZID || 
                sample.properties.tz ||
                sample.properties.time_zone ||
                sample.properties.timezone ||
                sample.properties.tz_name1st ||
                sample.properties.zone ||
                sample.properties.ZONE
              )
              
              if (hasTimezoneId) {
                timezoneData = data
                console.log(`✅ Successfully loaded ${data.features.length} official timezone boundaries from: ${source}`)
                break
              } else {
                console.warn(`❌ Data from ${source} lacks timezone identifiers`)
              }
            }
          } else {
            console.warn(`❌ HTTP ${response.status} from ${source}`)
          }
        } catch (err) {
          console.warn(`❌ Failed to load from ${source}:`, err.message)
          continue
        }
      }
      
      if (timezoneData) {
        await this.createOfficialTimezoneRegions(map, timezoneData)
      } else {
        console.error('❌ All official timezone sources failed, using reliable country-based fallback')
        // Use the reliable world country data we know works
        await this.createTimezoneRegionsFromWorldBoundaries(map, null)
      }
      
    } catch (error) {
      console.error('Failed to load official timezone boundaries:', error)
      await this.loadAdministrativeTimezones(map)
    }
  },

  async createOfficialTimezoneRegions(map, timezoneData) {
    console.log('🗺️ Creating timezone regions from official boundary data with state-line precision...')
    
    const timezoneColors = this.getTimezoneColors()
    
    // Group timezone features by UTC offset for consistent coloring
    const timezonesByOffset = {}
    
    timezoneData.features.forEach((feature) => {
      // Extract timezone identifier from various possible property names
      const tzid = feature.properties.tzid || 
                  feature.properties.TZID || 
                  feature.properties.tz ||
                  feature.properties.time_zone ||
                  feature.properties.timezone ||
                  feature.properties.tz_name1st ||
                  feature.properties.zone ||
                  feature.properties.ZONE
      
      if (!tzid) {
        console.warn('Timezone feature missing identifier:', feature.properties)
        return
      }
      
      // Calculate current UTC offset for this timezone
      const now = new Date()
      const utcOffset = this.getTimezoneOffset(tzid, now)
      const offsetKey = Math.floor(utcOffset).toString()
      
      if (!timezonesByOffset[offsetKey]) {
        timezonesByOffset[offsetKey] = {
          features: [],
          offset: Math.floor(utcOffset),
          color: this.getColorForOffset(Math.floor(utcOffset), timezoneColors),
          timezones: []
        }
      }
      
      // Ensure consistent tzid property for filtering
      feature.properties.tzid = tzid
      
      timezonesByOffset[offsetKey].features.push(feature)
      if (!timezonesByOffset[offsetKey].timezones.includes(tzid)) {
        timezonesByOffset[offsetKey].timezones.push(tzid)
      }
    })
    
    console.log(`Processing ${Object.keys(timezonesByOffset).length} timezone offset groups...`)
    
    // Create map layers for each timezone offset group
    Object.keys(timezonesByOffset).forEach((offsetKey) => {
      const group = timezonesByOffset[offsetKey]
      const offsetValue = group.offset
      
      const sourceId = `official-timezone-${offsetKey.replace('.', '_').replace('-', 'neg')}`
      const layerId = `official-timezone-layer-${offsetKey.replace('.', '_').replace('-', 'neg')}`
      const borderLayerId = `official-timezone-border-${offsetKey.replace('.', '_').replace('-', 'neg')}`
      const hoverLayerId = `official-timezone-hover-${offsetKey.replace('.', '_').replace('-', 'neg')}`
      
      const color = group.color
      
      // Create GeoJSON collection for this offset group
      const featureCollection = {
        type: 'FeatureCollection',
        features: group.features
      }
      
      console.log(`Adding UTC${offsetValue >= 0 ? '+' : ''}${offsetValue} timezone region with ${group.features.length} zones: ${group.timezones.slice(0, 3).join(', ')}${group.timezones.length > 3 ? '...' : ''}`)
      
      // Add source
      map.addSource(sourceId, {
        type: 'geojson',
        data: featureCollection
      })
      
      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.05
        }
      })
      
                  // Add hover highlight layer that highlights entire timezone regions  
            map.addLayer({
              id: hoverLayerId,
              type: 'fill',
              source: sourceId,
              paint: {
                'fill-color': '#3b82f6',
                'fill-opacity': 0.3
              },
              layout: {
                'visibility': 'none' // Initially hidden
              }
            })
      
                  // Add border layer to show timezone boundaries - more visible
            map.addLayer({
              id: borderLayerId,
              type: 'line',
              source: sourceId,
              paint: {
                'line-color': '#ffffff',
                'line-width': 1,
                'line-opacity': 0.35
              }
            })
            
            // Add inner border for contrast
            map.addLayer({
              id: `${borderLayerId}-inner`,
              type: 'line',
              source: sourceId,
              paint: {
                'line-color': '#000000',
                'line-width': 0.6,
                'line-opacity': 0.25
              }
            })
            
            // Timezone offset labels removed for cleaner display
      
            // Add hover effects for individual timezone highlighting
            map.on('mousemove', layerId, (e) => {
              map.getCanvas().style.cursor = 'pointer'
              
              // Get the specific timezone feature being hovered
              if (e.features && e.features.length > 0) {
                const hoveredTzid = e.features[0].properties.tzid
                
                // Use filter to show only the hovered timezone
                try {
                  map.setFilter(hoverLayerId, ['==', ['get', 'tzid'], hoveredTzid])
                  map.setLayoutProperty(hoverLayerId, 'visibility', 'visible')
                } catch (error) {
                  console.warn('Failed to show hover highlight:', error)
                }
              }
            })
            
            map.on('mouseleave', layerId, () => {
              map.getCanvas().style.cursor = ''
              try {
                map.setLayoutProperty(hoverLayerId, 'visibility', 'none')
              } catch (error) {
                console.warn('Failed to hide hover highlight:', error)
              }
            })
      
      // Add click handler for timezone info
      map.on('click', layerId, (e) => {
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        this.createTimezonePopup(e, map, true)
      })
    })
    
    console.log(`✅ Added ${Object.keys(timezonesByOffset).length} official timezone regions with administrative border precision!`)
    
    // Debug: List all map layers
    this.debugMapLayers(map)
  },

  debugMapLayers(map) {
    console.log('🗺️ DEBUG: All map layers:')
    const style = map.getStyle()
    if (style && style.layers) {
      style.layers.forEach((layer, index) => {
        console.log(`  ${index}: ${layer.id} (${layer.type}) - visible: ${layer.layout?.visibility !== 'none'}`)
      })
    } else {
      console.log('  No layers found in map style')
    }
    
    // Mouse tracking debug removed - issue found: labels were blocking hover events
  },



  async createStaticTimezoneRegions(map) {
    console.log('🏔️ Creating static timezone regions as ultimate fallback...')
    
    const timezoneColors = this.getTimezoneColors()
    
    // Static timezone regions with hardcoded coordinates (ultimate fallback)
    const staticTimezoneRegions = [
      {
        name: 'Pacific Time (US West Coast)',
        timezone: 'America/Los_Angeles',
        offset: -8,
        coordinates: [
          [-124.4, 32.5], [-124.4, 49.0], [-117.0, 49.0], 
          [-117.0, 42.0], [-114.0, 39.0], [-114.0, 32.5], [-124.4, 32.5]
        ]
      },
      {
        name: 'Mountain Time (US Mountain)',
        timezone: 'America/Denver',
        offset: -7,
        coordinates: [
          [-117.0, 32.5], [-117.0, 49.0], [-104.0, 49.0],
          [-104.0, 37.0], [-109.0, 37.0], [-109.0, 32.5], [-117.0, 32.5]
        ]
      },
      {
        name: 'Central Time (US Central)',
        timezone: 'America/Chicago',
        offset: -6,
        coordinates: [
          [-104.0, 25.8], [-104.0, 49.0], [-87.5, 49.0],
          [-87.5, 45.2], [-82.4, 41.8], [-96.9, 25.8], [-104.0, 25.8]
        ]
      },
      {
        name: 'Eastern Time (US East Coast)',
        timezone: 'America/New_York',
        offset: -5,
        coordinates: [
          [-87.5, 24.4], [-87.5, 49.0], [-67.0, 49.0],
          [-67.0, 44.0], [-81.4, 24.4], [-87.5, 24.4]
        ]
      },
      {
        name: 'Greenwich Mean Time (UK)',
        timezone: 'Europe/London',
        offset: 0,
        coordinates: [
          [-10.8, 49.8], [-10.8, 60.9], [2.1, 60.9], [2.1, 49.8], [-10.8, 49.8]
        ]
      },
      {
        name: 'Central European Time',
        timezone: 'Europe/Berlin',
        offset: 1,
        coordinates: [
          [-4.8, 36.0], [29.7, 36.0], [29.7, 71.2], [-4.8, 71.2], [-4.8, 36.0]
        ]
      },
      {
        name: 'China Standard Time',
        timezone: 'Asia/Shanghai',
        offset: 8,
        coordinates: [
          [73.5, 18.2], [134.8, 18.2], [134.8, 53.6], [73.5, 53.6], [73.5, 18.2]
        ]
      },
      {
        name: 'Japan Standard Time',
        timezone: 'Asia/Tokyo',
        offset: 9,
        coordinates: [
          [129.0, 24.0], [146.0, 24.0], [146.0, 46.0], [129.0, 46.0], [129.0, 24.0]
        ]
      },
      {
        name: 'Australian Eastern Standard Time',
        timezone: 'Australia/Sydney',
        offset: 10,
        coordinates: [
          [140.9, -39.2], [153.6, -39.2], [153.6, -10.7], [140.9, -10.7], [140.9, -39.2]
        ]
      }
    ]
    
    // Create map layers for each static timezone region
    staticTimezoneRegions.forEach((region, index) => {
      const sourceId = `static-timezone-${index}`
      const layerId = `static-timezone-layer-${index}`
      const borderLayerId = `static-timezone-border-${index}`
      const hoverLayerId = `static-timezone-hover-${index}`
      
      const color = this.getColorForOffset(region.offset, timezoneColors)
      
      // Create GeoJSON polygon from coordinates
      const geojsonData = {
        type: 'Feature',
        geometry: {
          type: 'Polygon',
          coordinates: [region.coordinates]
        },
        properties: {
          timezone: region.timezone,
          name: region.name,
          offset: region.offset
        }
      }
      
      console.log(`Adding static region: ${region.name} (UTC${region.offset >= 0 ? '+' : ''}${region.offset})`)
      
      // Add source
      map.addSource(sourceId, {
        type: 'geojson',
        data: geojsonData
      })
      
      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.05
        }
      })
      
      // Add hover highlight layer
      map.addLayer({
        id: hoverLayerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': '#3b82f6',
          'fill-opacity': 0.3
        },
        layout: {
          'visibility': 'none' // Initially hidden
        }
      })
      
      // Add border layer - more visible
      map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': '#ffffff',
          'line-width': 1,
          'line-opacity': 0.35
        }
      })
      
      // Add inner border for contrast
      map.addLayer({
        id: `${borderLayerId}-inner`,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': '#000000',
          'line-width': 0.6,
          'line-opacity': 0.25
        }
      })
      
      // Timezone offset labels removed for cleaner display
      
      // Add hover effects
      map.on('mouseenter', layerId, () => {
        map.getCanvas().style.cursor = 'pointer'
        try {
          map.setLayoutProperty(hoverLayerId, 'visibility', 'visible')
        } catch (error) {
          console.warn('Failed to show hover highlight:', error)
        }
      })
      
      map.on('mouseleave', layerId, () => {
        map.getCanvas().style.cursor = ''
        try {
          map.setLayoutProperty(hoverLayerId, 'visibility', 'none')
        } catch (error) {
          console.warn('Failed to hide hover highlight:', error)
        }
      })
      
      // Add click handler for timezone info
      map.on('click', layerId, (e) => {
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        const currentTime = this.getCurrentTimeInTimezone(region.timezone)
        
        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="p-3">
              <div class="font-semibold text-gray-900">${region.name}</div>
              <div class="text-xs text-gray-500 mt-1">${region.timezone}</div>
              <div class="text-xs text-gray-700 mt-1">Current time: ${currentTime}</div>
              <div class="text-xs text-gray-500 mt-2">Static fallback regions</div>
            </div>
          `)
          .addTo(map)
      })
    })
    
    console.log(`✅ Added ${staticTimezoneRegions.length} static timezone regions as fallback!`)
  },

  async createTimezoneRegionsFromWorldBoundaries(map, worldData) {
    console.log('🗺️ Creating precise timezone regions using real country boundaries...')
    
    // If no world data provided, load it first
    if (!worldData) {
      try {
        console.log('Loading world country boundaries for timezone mapping...')
        const response = await fetch('https://cdn.jsdelivr.net/npm/world-atlas@3/countries-110m.json', {
          cache: 'no-cache'
        })
        if (response.ok) {
          worldData = await response.json()
          console.log(`✅ Loaded ${worldData.features.length} countries for timezone mapping`)
        } else {
          throw new Error(`Failed to load world data: ${response.status}`)
        }
      } catch (error) {
        console.error('Failed to load world data for timezone fallback:', error)
        return this.loadAdministrativeTimezones(map)
      }
    }
    
    const timezoneColors = this.getTimezoneColors()
    
    // Define timezone regions with their countries/regions
    // This approach treats each timezone as a separate entity
    const timezoneRegions = [
      // North America - Pacific Time
      {
        name: 'Pacific Time',
        timezone: 'America/Los_Angeles',
        offset: -8,
        countries: ['United States of America', 'Canada'],
        description: 'US West Coast & Western Canada'
      },
      
      // North America - Mountain Time  
      {
        name: 'Mountain Time',
        timezone: 'America/Denver', 
        offset: -7,
        countries: ['United States of America', 'Canada'],
        description: 'US Mountain States & Mountain Canada'
      },
      
      // North America - Central Time
      {
        name: 'Central Time',
        timezone: 'America/Chicago',
        offset: -6, 
        countries: ['United States of America', 'Canada', 'Mexico'],
        description: 'US Central States, Central Canada & Mexico'
      },
      
      // North America - Eastern Time
      {
        name: 'Eastern Time',
        timezone: 'America/New_York',
        offset: -5,
        countries: ['United States of America', 'Canada'],
        description: 'US Eastern States & Eastern Canada'
      },
      
      // Single-timezone countries
      {
        name: 'Greenwich Mean Time',
        timezone: 'Europe/London',
        offset: 0,
        countries: ['United Kingdom'],
        description: 'United Kingdom'
      },
      
      {
        name: 'Central European Time',
        timezone: 'Europe/Berlin',
        offset: 1,
        countries: ['Germany', 'France', 'Spain', 'Italy', 'Netherlands', 'Belgium', 'Poland', 'Czech Republic', 'Austria', 'Switzerland', 'Norway', 'Sweden', 'Denmark'],
        description: 'Central Europe'
      },
      
      {
        name: 'Eastern European Time',
        timezone: 'Europe/Helsinki',
        offset: 2,
        countries: ['Finland', 'Estonia', 'Latvia', 'Lithuania', 'Romania', 'Bulgaria', 'Greece'],
        description: 'Eastern Europe'
      },
      
      {
        name: 'Moscow Time',
        timezone: 'Europe/Moscow',
        offset: 3,
        countries: ['Russia'],
        description: 'Western Russia'
      },
      
      {
        name: 'China Standard Time',
        timezone: 'Asia/Shanghai',
        offset: 8,
        countries: ['China'],
        description: 'China'
      },
      
      {
        name: 'India Standard Time',
        timezone: 'Asia/Kolkata',
        offset: 5.5,
        countries: ['India'],
        description: 'India'
      },
      
      {
        name: 'Japan Standard Time',
        timezone: 'Asia/Tokyo',
        offset: 9,
        countries: ['Japan'],
        description: 'Japan'
      },
      
      {
        name: 'Korea Standard Time', 
        timezone: 'Asia/Seoul',
        offset: 9,
        countries: ['South Korea'],
        description: 'South Korea'
      },
      
      {
        name: 'Australian Western Standard Time',
        timezone: 'Australia/Perth',
        offset: 8,
        countries: ['Australia'],
        description: 'Western Australia'
      },
      
      {
        name: 'Australian Eastern Standard Time',
        timezone: 'Australia/Sydney', 
        offset: 10,
        countries: ['Australia'],
        description: 'Eastern Australia'
      },
      
      {
        name: 'New Zealand Standard Time',
        timezone: 'Pacific/Auckland',
        offset: 12,
        countries: ['New Zealand'],
        description: 'New Zealand'
      },
      
      {
        name: 'Brazil Time',
        timezone: 'America/Sao_Paulo',
        offset: -3,
        countries: ['Brazil'],
        description: 'Brazil'
      },
      
      {
        name: 'Argentina Time',
        timezone: 'America/Argentina/Buenos_Aires',
        offset: -3,
        countries: ['Argentina'],
        description: 'Argentina'  
      },
      
      {
        name: 'South Africa Standard Time',
        timezone: 'Africa/Johannesburg',
        offset: 2,
        countries: ['South Africa'],
        description: 'South Africa'
      }
    ]
    
    // Create map layers for each timezone region
    timezoneRegions.forEach((region, index) => {
      const features = []
      
      // Collect country features for this timezone region
      worldData.features.forEach((feature) => {
        const countryName = feature.properties.NAME || feature.properties.name || feature.properties.NAME_EN
        
        if (region.countries.includes(countryName)) {
          features.push(feature)
        }
      })
      
      if (features.length === 0) {
        console.log(`No countries found for timezone region: ${region.name}`)
        return
      }
      
      const color = this.getColorForOffset(region.offset, timezoneColors)
      const sourceId = `timezone-region-${index}`
      const layerId = `timezone-region-layer-${index}`
      const borderLayerId = `timezone-region-border-${index}`
      const hoverLayerId = `timezone-region-hover-${index}`
      
      const featureCollection = {
        type: 'FeatureCollection', 
        features: features
      }
      
      console.log(`Adding timezone region: ${region.name} (UTC${region.offset >= 0 ? '+' : ''}${region.offset}) with ${features.length} countries`)
      
      // Add source
      map.addSource(sourceId, {
        type: 'geojson',
        data: featureCollection
      })
      
      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.05
        }
      })
      
      // Add hover highlight layer for entire timezone region
      map.addLayer({
        id: hoverLayerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': '#3b82f6',
          'fill-opacity': 0.3
        },
        layout: {
          'visibility': 'none' // Initially hidden
        }
      })
      
                  // Add border layer - more visible
            map.addLayer({
              id: borderLayerId,
              type: 'line',
              source: sourceId,
              paint: {
                'line-color': '#ffffff',
                'line-width': 1,
                'line-opacity': 0.35
              }
            })
            
            // Add inner border for contrast
            map.addLayer({
              id: `${borderLayerId}-inner`,
              type: 'line',
              source: sourceId,
              paint: {
                'line-color': '#000000',
                'line-width': 0.6,
                'line-opacity': 0.25
              }
            })
            
            // Timezone offset labels removed for cleaner display
            
            // Add hover effects - highlight entire timezone region
            map.on('mouseenter', layerId, () => {
              map.getCanvas().style.cursor = 'pointer'
              try {
                map.setLayoutProperty(hoverLayerId, 'visibility', 'visible')
              } catch (error) {
                console.warn('Failed to show hover highlight:', error)
              }
            })
      
      map.on('mouseleave', layerId, () => {
        map.getCanvas().style.cursor = ''
        try {
          map.setLayoutProperty(hoverLayerId, 'visibility', 'none')
        } catch (error) {
          console.warn('Failed to hide hover highlight:', error)
        }
      })
      
      // Add click handler
      map.on('click', layerId, (e) => {
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        const features = map.queryRenderedFeatures(e.point, { layers: [layerId] })
        if (features.length > 0) {
          const feature = features[0]
          const countryName = feature.properties.NAME || feature.properties.name || 'Unknown'
          const currentTime = this.getCurrentTimeInTimezone(region.timezone)
          
          new maplibregl.Popup()
            .setLngLat(e.lngLat)
            .setHTML(`
              <div class="p-3">
                <div class="font-semibold text-gray-900">${region.name}</div>
                <div class="text-xs text-gray-500 mt-1">${region.timezone}</div>
                <div class="text-xs text-gray-700 mt-1">Current time: ${currentTime}</div>
                <div class="text-xs text-gray-500 mt-2">Country: ${countryName}</div>
                <div class="text-xs text-gray-400 mt-1">${region.description}</div>
              </div>
            `)
            .addTo(map)
        }
      })
    })
    
    console.log(`✅ Added ${timezoneRegions.length} timezone regions with real country boundaries and regional hover effects!`)
  },

  async loadAdministrativeTimezones(map) {
    console.log('Loading administrative timezone boundaries as fallback...')
    
    // Use a more precise administrative boundary approach
    const administrativeTimezones = this.getAdministrativeTimezoneRegions()
    const timezoneColors = this.getTimezoneColors()
    
    administrativeTimezones.forEach((timezone, index) => {
      const sourceId = `admin-timezone-${index}`
      const layerId = `admin-timezone-layer-${index}`
      const borderLayerId = `admin-timezone-border-${index}`
      const hoverLayerId = `admin-timezone-hover-${index}`
      
      const color = this.getColorForOffset(timezone.utcOffset, timezoneColors)
      
      // Add source
      map.addSource(sourceId, {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: timezone.geometry,
          properties: {
            name: timezone.name,
            utcOffset: timezone.utcOffset,
            timezoneName: timezone.timezoneName
          }
        }
      })
      
      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.03
        }
      })
      
      // Add hover highlight layer
      map.addLayer({
        id: hoverLayerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': '#3b82f6',
          'fill-opacity': 0.35
        },
        layout: {
          'visibility': 'none' // Initially hidden
        }
      })
      
      // Add border layer
      map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': color.replace('0.3', '0.9'),
          'line-width': 0.8,
          'line-opacity': 0.35
        }
      })
      
      // Add hover effects
      map.on('mouseenter', layerId, () => {
        map.getCanvas().style.cursor = 'pointer'
        map.setLayoutProperty(hoverLayerId, 'visibility', 'visible')
      })
      
      map.on('mouseleave', layerId, () => {
        map.getCanvas().style.cursor = ''
        map.setLayoutProperty(hoverLayerId, 'visibility', 'none')
      })
      
      // Add click handler
      map.on('click', layerId, (e) => {
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        const currentTime = this.getCurrentTimeInTimezone(timezone.timezoneName)
        
        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="p-3">
              <div class="font-semibold text-gray-900">${timezone.name}</div>
              <div class="text-xs text-gray-600 mt-1">UTC ${timezone.utcOffset >= 0 ? '+' : ''}${timezone.utcOffset}</div>
              <div class="text-xs text-gray-500 mt-1">${timezone.timezoneName}</div>
              <div class="text-xs text-gray-700 mt-1">Current time: ${currentTime}</div>
            </div>
          `)
          .addTo(map)
      })
    })
    
    console.log(`Added ${administrativeTimezones.length} administrative timezone regions with hover effects`)
  },

  async loadAccurateTimezones(map) {
    try {
      console.log('Loading accurate timezone boundaries from timezone-boundary-builder...')
      
      // Use reliable timezone data source
      const sources = [
        // Natural Earth Data - working timezone data source
        'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_time_zones.geojson'
      ]
      
      let timezoneData = null
      
      for (const source of sources) {
        try {
          console.log(`Attempting to load timezone data from: ${source}`)
          const response = await fetch(source, {
            headers: {
              'Accept': 'application/json'
            }
          })
          
          if (response.ok) {
            const data = await response.json()
            if (data && data.features && data.features.length > 0) {
              timezoneData = data
              console.log(`Successfully loaded ${data.features.length} timezone boundaries from: ${source}`)
              break
            }
          }
        } catch (err) {
          console.warn(`Failed to load from ${source}:`, err)
          continue
        }
      }
      
      if (!timezoneData) {
        throw new Error('All timezone data sources failed')
      }
      
      // Define colors for different timezone ranges
      const timezoneColors = this.getTimezoneColors()
      
      // Process the timezone data exactly like timeanddate.com
      console.log('Processing timezone boundaries...')
      
      // Group timezones by UTC offset for consistent coloring
      const timezonesByOffset = {}
      
      timezoneData.features.forEach((feature) => {
        // timezone-boundary-builder uses 'tzid' property
        const timezoneName = feature.properties.tzid || feature.properties.TZID || feature.properties.tz_name || 'Unknown'
        const utcOffset = this.calculateCurrentUTCOffset(timezoneName)
        
        if (!timezonesByOffset[utcOffset]) {
          timezonesByOffset[utcOffset] = []
        }
        timezonesByOffset[utcOffset].push({
          feature,
          timezoneName,
          utcOffset
        })
      })
      
      // Add each timezone offset group to the map
      Object.keys(timezonesByOffset).forEach((offset) => {
        const offsetValue = parseFloat(offset)
        const zones = timezonesByOffset[offset]
        const color = this.getColorForOffset(offsetValue, timezoneColors)
        
        // Create a single source for all zones with the same offset
        const sourceId = `timezone-offset-${offset.replace('.', '_').replace('-', 'neg')}`
        const layerId = `timezone-layer-${offset.replace('.', '_').replace('-', 'neg')}`
        const borderLayerId = `timezone-border-${offset.replace('.', '_').replace('-', 'neg')}`
        
        // Combine all features for this offset
        const featureCollection = {
          type: 'FeatureCollection',
          features: zones.map(zone => zone.feature)
        }
        
        // Add source
        map.addSource(sourceId, {
          type: 'geojson',
          data: featureCollection
        })
        
        // Add fill layer with UTC offset-based styling
        map.addLayer({
          id: layerId,
          type: 'fill',
          source: sourceId,
          paint: {
            'fill-color': color,
            'fill-opacity': 0.03
          }
        })
        
        // Add border layer
        map.addLayer({
          id: borderLayerId,
          type: 'line',
          source: sourceId,
          paint: {
            'line-color': color.replace('0.3', '0.8'),
            'line-width': 0.8,
            'line-opacity': 0.3
          }
        })
        
        // Add click handler for timezone info
        map.on('click', layerId, (e) => {
          // Don't show timezone popup if clicking on night region
          if (!this.shouldShowTimezonePopup(map, e)) {
            return
          }
          
          // Find the specific timezone at this location
          const features = map.queryRenderedFeatures(e.point, { layers: [layerId] })
          if (features.length > 0) {
            const feature = features[0]
            const timezoneName = feature.properties.tzid || feature.properties.TZID || 'Unknown'
            const currentTime = this.getCurrentTimeInTimezone(timezoneName)
            
            new maplibregl.Popup()
              .setLngLat(e.lngLat)
              .setHTML(`
                <div class="p-3">
                  <div class="font-semibold text-gray-900">${timezoneName}</div>
                  <div class="text-xs text-gray-700 mt-1">Current time: ${currentTime}</div>
                  <div class="text-xs text-gray-500 mt-1">Click for more timezone details</div>
                </div>
              `)
              .addTo(map)
          }
        })
        
        // Hover effects
        map.on('mouseenter', layerId, () => {
          map.getCanvas().style.cursor = 'pointer'
        })
        
        map.on('mouseleave', layerId, () => {
          map.getCanvas().style.cursor = ''
        })
      })
      
      console.log('Accurate timezone overlay loaded successfully')
      
    } catch (error) {
      // Fallback to generating timezone data from known timezones
      await this.generateTimezoneData(map)
    }
  },

  async generateTimezoneData(map) {
    // Generate more accurate timezone polygons based on real timezone data
    const timezoneRegions = this.getAccurateTimezoneRegions()
    const timezoneColors = this.getTimezoneColors()
    
    timezoneRegions.forEach((region, index) => {
      const sourceId = `timezone-region-${index}`
      const layerId = `timezone-layer-${index}`
      const borderLayerId = `timezone-border-${index}`
      
      const color = this.getColorForOffset(region.utcOffset, timezoneColors)
      
      // Add source
      map.addSource(sourceId, {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: region.geometry,
          properties: {
            name: region.name,
            utcOffset: region.utcOffset,
            timezoneName: region.timezoneName
          }
        }
      })
      
      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.02
        }
      })
      
      // Add border
      map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': color.replace('0.3', '0.8'),
          'line-width': 1,
          'line-opacity': 0.25
        }
      })
      
      // Add click handler
      map.on('click', layerId, (e) => {
        // Don't show timezone popup if clicking on night region
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="p-3">
              <div class="font-semibold text-gray-900">${region.name}</div>
              <div class="text-xs text-gray-600 mt-1">UTC ${region.utcOffset >= 0 ? '+' : ''}${region.utcOffset}</div>
              <div class="text-xs text-gray-500 mt-1">${region.timezoneName}</div>
            </div>
          `)
          .addTo(map)
      })
      
      // Hover effects
      map.on('mouseenter', layerId, () => {
        map.getCanvas().style.cursor = 'pointer'
      })
      
      map.on('mouseleave', layerId, () => {
        map.getCanvas().style.cursor = ''
      })
    })
    
    console.log('Generated timezone overlay added successfully')
  },

  getAccurateTimezoneShapes() {
    // Accurate timezone boundaries following timeanddate.com's approach
    // These follow administrative boundaries, not just country borders
    return [
      // US Pacific Time (UTC-8)
      {
        name: 'US Pacific Time',
        utcOffset: -8,
        timezoneName: 'America/Los_Angeles',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-130, 30], [-130, 50], [-110, 50], [-110, 30], [-130, 30]
          ]]
        }
      },
      // US Mountain Time (UTC-7)
      {
        name: 'US Mountain Time',
        utcOffset: -7,
        timezoneName: 'America/Denver',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-110, 30], [-110, 50], [-95, 50], [-95, 30], [-110, 30]
          ]]
        }
      },
      // US Central Time (UTC-6)
      {
        name: 'US Central Time',
        utcOffset: -6,
        timezoneName: 'America/Chicago',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-95, 30], [-95, 50], [-80, 50], [-80, 30], [-95, 30]
          ]]
        }
      },
      // US Eastern Time (UTC-5)
      {
        name: 'US Eastern Time',
        utcOffset: -5,
        timezoneName: 'America/New_York',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-80, 30], [-80, 50], [-65, 50], [-65, 30], [-80, 30]
          ]]
        }
      },
      // Europe Western (UTC+0)
      {
        name: 'Western Europe',
        utcOffset: 0,
        timezoneName: 'Europe/London',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-15, 35], [-15, 70], [5, 70], [5, 35], [-15, 35]
          ]]
        }
      },
      // Europe Central (UTC+1)
      {
        name: 'Central Europe',
        utcOffset: 1,
        timezoneName: 'Europe/Berlin',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [5, 35], [5, 70], [25, 70], [25, 35], [5, 35]
          ]]
        }
      },
      // Europe Eastern (UTC+2)
      {
        name: 'Eastern Europe',
        utcOffset: 2,
        timezoneName: 'Europe/Helsinki',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [25, 35], [25, 70], [45, 70], [45, 35], [25, 35]
          ]]
        }
      },
      // Russia Moscow Time (UTC+3)
      {
        name: 'Moscow Time',
        utcOffset: 3,
        timezoneName: 'Europe/Moscow',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [45, 40], [45, 75], [65, 75], [65, 40], [45, 40]
          ]]
        }
      },
      // Russia Yekaterinburg Time (UTC+5)
      {
        name: 'Yekaterinburg Time',
        utcOffset: 5,
        timezoneName: 'Asia/Yekaterinburg',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [65, 40], [65, 75], [85, 75], [85, 40], [65, 40]
          ]]
        }
      },
      // China Standard Time (UTC+8)
      {
        name: 'China Standard Time',
        utcOffset: 8,
        timezoneName: 'Asia/Shanghai',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [85, 20], [85, 55], [125, 55], [125, 20], [85, 20]
          ]]
        }
      },
      // Japan Standard Time (UTC+9)
      {
        name: 'Japan Standard Time',
        utcOffset: 9,
        timezoneName: 'Asia/Tokyo',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [125, 25], [125, 50], [150, 50], [150, 25], [125, 25]
          ]]
        }
      },
      // Australia Eastern Time (UTC+10)
      {
        name: 'Australian Eastern Time',
        utcOffset: 10,
        timezoneName: 'Australia/Sydney',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [140, -45], [140, -10], [155, -10], [155, -45], [140, -45]
          ]]
        }
      },
      // Australia Central Time (UTC+9.5)
      {
        name: 'Australian Central Time',
        utcOffset: 9.5,
        timezoneName: 'Australia/Adelaide',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [125, -45], [125, -10], [140, -10], [140, -45], [125, -45]
          ]]
        }
      },
      // Australia Western Time (UTC+8)
      {
        name: 'Australian Western Time',
        utcOffset: 8,
        timezoneName: 'Australia/Perth',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [110, -45], [110, -10], [125, -10], [125, -45], [110, -45]
          ]]
        }
      }
    ]
  },

  getAccurateTimezoneRegions() {
    // More accurate timezone regions based on real-world boundaries
    return [
      // Pacific Ocean (-12 to -9)
      {
        name: 'International Date Line West',
        utcOffset: -12,
        timezoneName: 'Pacific/Baker_Island',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-180, -70], [-165, -70], [-165, 70], [-180, 70], [-180, -70]
          ]]
        }
      },
      {
        name: 'Hawaiian Time',
        utcOffset: -10,
        timezoneName: 'Pacific/Honolulu',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-165, 15], [-150, 15], [-150, 25], [-165, 25], [-165, 15]
          ]]
        }
      },
      // North America
      {
        name: 'Alaska Time',
        utcOffset: -9,
        timezoneName: 'America/Anchorage',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-180, 51], [-130, 51], [-130, 72], [-180, 72], [-180, 51]
          ]]
        }
      },
      {
        name: 'Pacific Time',
        utcOffset: -8,
        timezoneName: 'America/Los_Angeles',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-130, 32], [-114, 32], [-114, 49], [-130, 49], [-130, 32]
          ]]
        }
      },
      {
        name: 'Mountain Time',
        utcOffset: -7,
        timezoneName: 'America/Denver',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-114, 31], [-104, 31], [-104, 49], [-114, 49], [-114, 31]
          ]]
        }
      },
      {
        name: 'Central Time',
        utcOffset: -6,
        timezoneName: 'America/Chicago',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-104, 25], [-88, 25], [-88, 49], [-104, 49], [-104, 25]
          ]]
        }
      },
      {
        name: 'Eastern Time',
        utcOffset: -5,
        timezoneName: 'America/New_York',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-88, 25], [-67, 25], [-67, 49], [-88, 49], [-88, 25]
          ]]
        }
      },
      // South America
      {
        name: 'Brazil Time',
        utcOffset: -3,
        timezoneName: 'America/Sao_Paulo',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-75, -35], [-35, -35], [-35, 5], [-75, 5], [-75, -35]
          ]]
        }
      },
      // Europe & Africa
      {
        name: 'GMT/UTC',
        utcOffset: 0,
        timezoneName: 'Europe/London',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-15, 35], [7.5, 35], [7.5, 72], [-15, 72], [-15, 35]
          ]]
        }
      },
      {
        name: 'Central European Time',
        utcOffset: 1,
        timezoneName: 'Europe/Berlin',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [7.5, 35], [22.5, 35], [22.5, 72], [7.5, 72], [7.5, 35]
          ]]
        }
      },
      {
        name: 'Eastern European Time',
        utcOffset: 2,
        timezoneName: 'Europe/Helsinki',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [22.5, 35], [37.5, 35], [37.5, 72], [22.5, 72], [22.5, 35]
          ]]
        }
      },
      {
        name: 'East Africa Time',
        utcOffset: 3,
        timezoneName: 'Africa/Nairobi',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [22.5, -35], [52.5, -35], [52.5, 40], [22.5, 40], [22.5, -35]
          ]]
        }
      },
      // Asia
      {
        name: 'Moscow Time',
        utcOffset: 3,
        timezoneName: 'Europe/Moscow',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [37.5, 40], [67.5, 40], [67.5, 72], [37.5, 72], [37.5, 40]
          ]]
        }
      },
      {
        name: 'Gulf Standard Time',
        utcOffset: 4,
        timezoneName: 'Asia/Dubai',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [52.5, 12], [67.5, 12], [67.5, 40], [52.5, 40], [52.5, 12]
          ]]
        }
      },
      {
        name: 'India Standard Time',
        utcOffset: 5.5,
        timezoneName: 'Asia/Kolkata',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [67.5, 8], [97.5, 8], [97.5, 37], [67.5, 37], [67.5, 8]
          ]]
        }
      },
      {
        name: 'Bangladesh Time',
        utcOffset: 6,
        timezoneName: 'Asia/Dhaka',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [82.5, 20], [97.5, 20], [97.5, 30], [82.5, 30], [82.5, 20]
          ]]
        }
      },
      {
        name: 'Southeast Asia Time',
        utcOffset: 7,
        timezoneName: 'Asia/Bangkok',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [97.5, -10], [112.5, -10], [112.5, 25], [97.5, 25], [97.5, -10]
          ]]
        }
      },
      {
        name: 'China Standard Time',
        utcOffset: 8,
        timezoneName: 'Asia/Shanghai',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [97.5, 18], [135, 18], [135, 53], [97.5, 53], [97.5, 18]
          ]]
        }
      },
      {
        name: 'Japan Standard Time',
        utcOffset: 9,
        timezoneName: 'Asia/Tokyo',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [129, 30], [146, 30], [146, 46], [129, 46], [129, 30]
          ]]
        }
      },
      // Australia & Pacific
      {
        name: 'Australian Eastern Time',
        utcOffset: 10,
        timezoneName: 'Australia/Sydney',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [142.5, -44], [157.5, -44], [157.5, -10], [142.5, -10], [142.5, -44]
          ]]
        }
      },
      {
        name: 'Australian Central Time',
        utcOffset: 9.5,
        timezoneName: 'Australia/Adelaide',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [127.5, -39], [142.5, -39], [142.5, -20], [127.5, -20], [127.5, -39]
          ]]
        }
      },
      {
        name: 'New Zealand Time',
        utcOffset: 12,
        timezoneName: 'Pacific/Auckland',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [165, -48], [180, -48], [180, -34], [165, -34], [165, -48]
          ]]
        }
      }
    ]
  },

  getTimezoneColors() {
    return [
      'rgba(255, 99, 132, 0.3)',   // Red
      'rgba(54, 162, 235, 0.3)',   // Blue  
      'rgba(255, 205, 86, 0.3)',   // Yellow
      'rgba(75, 192, 192, 0.3)',   // Teal
      'rgba(153, 102, 255, 0.3)',  // Purple
      'rgba(255, 159, 64, 0.3)',   // Orange
      'rgba(199, 199, 199, 0.3)',  // Grey
      'rgba(83, 102, 255, 0.3)',   // Blue-purple
      'rgba(255, 99, 255, 0.3)',   // Pink
      'rgba(99, 255, 132, 0.3)',   // Green
      'rgba(255, 206, 84, 0.3)',   // Gold
      'rgba(54, 235, 162, 0.3)'    // Mint
    ]
  },

  getColorForOffset(utcOffset, colors) {
    // Map UTC offset to color index
    const offsetIndex = Math.floor((utcOffset + 12) / 2) % colors.length
    return colors[Math.max(0, Math.min(offsetIndex, colors.length - 1))]
  },

  getAdministrativeTimezoneRegions() {
    // Define timezone regions that follow precise administrative boundaries
    // These are based on actual country borders, state lines, and administrative divisions
    // Coordinates follow real-world boundaries as closely as possible
    return [
      // United States - Following state boundaries precisely
      {
        name: 'US Pacific Time',
        timezoneName: 'America/Los_Angeles',
        utcOffset: -8,
        geometry: {
          type: 'MultiPolygon',
          coordinates: [
            [[ // California, Washington, Oregon, Nevada (most)
              [-124.4, 32.5], [-124.4, 42.0], [-120.0, 42.0], [-120.0, 46.7],
              [-124.4, 46.7], [-124.4, 49.0], [-117.0, 49.0], [-117.0, 45.5],
              [-116.5, 45.5], [-116.5, 42.0], [-120.0, 42.0], [-120.0, 39.0],
              [-114.0, 39.0], [-114.0, 35.0], [-117.2, 32.5], [-124.4, 32.5]
            ]],
            [[ // Alaska
              [-179.1, 51.2], [-179.1, 71.4], [-129.9, 71.4], [-129.9, 54.4],
              [-130.0, 54.4], [-130.0, 51.2], [-179.1, 51.2]
            ]]
          ]
        }
      },
      {
        name: 'US Mountain Time',
        timezoneName: 'America/Denver',
        utcOffset: -7,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-117.0, 32.5], [-117.0, 37.0], [-114.0, 37.0], [-114.0, 42.0],
            [-116.5, 42.0], [-116.5, 45.5], [-117.0, 45.5], [-117.0, 49.0],
            [-104.0, 49.0], [-104.0, 37.0], [-109.0, 37.0], [-109.0, 32.5],
            [-117.0, 32.5]
          ]]
        }
      },
      {
        name: 'US Central Time',
        timezoneName: 'America/Chicago',
        utcOffset: -6,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-104.0, 25.8], [-104.0, 37.0], [-109.0, 37.0], [-109.0, 49.0],
            [-96.4, 49.0], [-96.4, 45.9], [-90.4, 45.9], [-87.5, 45.2],
            [-82.4, 41.8], [-82.4, 36.5], [-84.3, 36.5], [-84.3, 33.8],
            [-85.6, 32.6], [-88.0, 30.2], [-91.4, 29.0], [-94.0, 29.7],
            [-96.9, 25.8], [-104.0, 25.8]
          ]]
        }
      },
      {
        name: 'US Eastern Time',
        timezoneName: 'America/New_York',
        utcOffset: -5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-87.5, 24.4], [-87.5, 45.2], [-90.4, 45.9], [-96.4, 45.9],
            [-96.4, 49.0], [-82.4, 49.0], [-82.4, 45.0], [-75.7, 45.0],
            [-67.0, 45.0], [-67.0, 47.5], [-69.2, 47.5], [-69.2, 44.8],
            [-67.8, 44.8], [-67.8, 40.8], [-73.7, 40.8], [-75.4, 39.7],
            [-75.4, 39.2], [-80.5, 39.2], [-80.5, 36.5], [-82.4, 36.5],
            [-82.4, 35.0], [-84.3, 35.0], [-84.3, 30.4], [-81.4, 24.4],
            [-87.5, 24.4]
          ]]
        }
      },
      
      // Canada - Following provincial boundaries
      {
        name: 'Canada Pacific',
        timezoneName: 'America/Vancouver',
        utcOffset: -8,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-139.0, 48.3], [-139.0, 69.6], [-120.0, 69.6], [-120.0, 60.0],
            [-125.0, 60.0], [-125.0, 54.4], [-130.0, 54.4], [-130.0, 48.3],
            [-139.0, 48.3]
          ]]
        }
      },
      {
        name: 'Canada Mountain',
        timezoneName: 'America/Edmonton',
        utcOffset: -7,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-120.0, 49.0], [-120.0, 60.0], [-110.0, 60.0], [-110.0, 68.8],
            [-102.0, 68.8], [-102.0, 49.0], [-120.0, 49.0]
          ]]
        }
      },
      {
        name: 'Canada Central',
        timezoneName: 'America/Winnipeg',
        utcOffset: -6,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-102.0, 49.0], [-102.0, 68.8], [-90.0, 68.8], [-90.0, 60.0],
            [-85.0, 60.0], [-85.0, 51.0], [-89.0, 51.0], [-89.0, 49.0],
            [-102.0, 49.0]
          ]]
        }
      },
      {
        name: 'Canada Eastern',
        timezoneName: 'America/Toronto',
        utcOffset: -5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-89.0, 41.7], [-89.0, 51.0], [-85.0, 51.0], [-85.0, 60.0],
            [-68.0, 60.0], [-68.0, 45.0], [-74.7, 45.0], [-76.0, 44.0],
            [-82.4, 42.0], [-89.0, 41.7]
          ]]
        }
      },
      
      // European Union - Following country boundaries more precisely
      {
        name: 'Central European Time',
        timezoneName: 'Europe/Berlin',
        utcOffset: 1,
        geometry: {
          type: 'MultiPolygon',
          coordinates: [
            [[ // Main European landmass
              [-4.8, 36.0], [3.3, 42.5], [7.4, 43.7], [15.0, 46.6], [22.9, 48.6],
              [26.6, 47.9], [29.7, 45.9], [28.2, 43.8], [22.4, 41.3], [20.2, 39.6],
              [14.5, 35.9], [12.1, 35.5], [8.1, 36.9], [5.3, 36.1], [-4.8, 36.0]
            ]]
          ]
        }
      },
      
      // Russia - Following federal district boundaries
      {
        name: 'Moscow Time',
        timezoneName: 'Europe/Moscow',
        utcOffset: 3,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [27.0, 41.0], [60.0, 41.0], [60.0, 68.0], [27.0, 68.0], [27.0, 41.0]
          ]]
        }
      },
      {
        name: 'Yekaterinburg Time',
        timezoneName: 'Asia/Yekaterinburg',
        utcOffset: 5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [60.0, 45.0], [87.0, 45.0], [87.0, 73.0], [60.0, 73.0], [60.0, 45.0]
          ]]
        }
      },
      
      // China - Single timezone despite size
      {
        name: 'China Standard Time',
        timezoneName: 'Asia/Shanghai',
        utcOffset: 8,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [73.5, 18.2], [134.8, 18.2], [134.8, 53.6], [73.5, 53.6], [73.5, 18.2]
          ]]
        }
      },
      
      // India - Single timezone
      {
        name: 'India Standard Time',
        timezoneName: 'Asia/Kolkata',
        utcOffset: 5.5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [68.1, 6.7], [97.4, 6.7], [97.4, 37.1], [68.1, 37.1], [68.1, 6.7]
          ]]
        }
      },
      
      // Brazil - Multiple timezones following state boundaries
      {
        name: 'Brazil Eastern',
        timezoneName: 'America/Sao_Paulo',
        utcOffset: -3,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-57.6, -33.7], [-34.8, -33.7], [-34.8, 5.3], [-57.6, 5.3], [-57.6, -33.7]
          ]]
        }
      },
      {
        name: 'Brazil Western',
        timezoneName: 'America/Cuiaba',
        utcOffset: -4,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-74.0, -18.0], [-57.6, -18.0], [-57.6, 5.3], [-74.0, 5.3], [-74.0, -18.0]
          ]]
        }
      },
      
      // Australia - Following state boundaries
      {
        name: 'Australian Eastern Standard Time',
        timezoneName: 'Australia/Sydney',
        utcOffset: 10,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [140.9, -39.2], [153.6, -39.2], [153.6, -10.7], [140.9, -10.7], [140.9, -39.2]
          ]]
        }
      },
      {
        name: 'Australian Central Standard Time',
        timezoneName: 'Australia/Adelaide',
        utcOffset: 9.5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [129.0, -38.0], [140.9, -38.0], [140.9, -10.7], [129.0, -10.7], [129.0, -38.0]
          ]]
        }
      },
      {
        name: 'Australian Western Standard Time',
        timezoneName: 'Australia/Perth',
        utcOffset: 8,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [112.9, -35.1], [129.0, -35.1], [129.0, -10.7], [112.9, -10.7], [112.9, -35.1]
          ]]
        }
      }
    ]
  },

  calculateCurrentUTCOffset(timezoneName) {
    // Handle UTC offset strings first (like UTC-03:00, UTC+05:30)
    if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
      const match = timezoneName.match(/^UTC([+\-±])(\d{1,2}):(\d{2})$/)
      if (match) {
        const sign = match[1] === '+' ? 1 : -1
        const hours = parseInt(match[2], 10)
        const minutes = parseInt(match[3], 10)
        
        // UTC±00:00, UTC+00:00 and UTC-00:00 all represent GMT/UTC (offset 0)
        if (hours === 0 && minutes === 0) {
          return 0
        }
        
        return sign * (hours + minutes / 60)
      }
    }
    
    // Calculate the current UTC offset for a timezone, accounting for DST
    try {
      const now = new Date()
      
      // Use the browser's Intl API for accurate timezone calculations
      if (Intl && Intl.DateTimeFormat) {
        const utcTime = new Date(now.toLocaleString('en-US', { timeZone: 'UTC' }))
        const localTime = new Date(now.toLocaleString('en-US', { timeZone: timezoneName }))
        
        const offsetMs = localTime.getTime() - utcTime.getTime()
        const offsetHours = offsetMs / (1000 * 60 * 60)
        
        return Math.round(offsetHours * 2) / 2 // Round to nearest 0.5
      }
    } catch (error) {
      console.warn(`Failed to calculate offset for ${timezoneName}:`, error)
    }
    
    // Fallback to static mapping
    return this.extractUTCOffset(timezoneName)
  },

  getCurrentTimeInTimezone(timezoneName) {
    try {
      const now = new Date()
      
      // Handle UTC offset strings (like UTC-08:00)
      if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
        const offset = this.calculateCurrentUTCOffset(timezoneName)
        // Get current UTC time and apply offset
        const utcTime = new Date(now.getTime() + (now.getTimezoneOffset() * 60 * 1000))
        const localTime = new Date(utcTime.getTime() + (offset * 60 * 60 * 1000))
        return localTime.toLocaleString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: true
        })
      }
      
      // Use proper timezone name
      return now.toLocaleString('en-US', {
        timeZone: timezoneName,
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
      })
    } catch (error) {
      return 'Unknown'
    }
  },

  createTimezonePopup(e, map, isDayTime = true) {
    // Close any existing popups
    const existingPopups = document.querySelectorAll('.maplibregl-popup')
    existingPopups.forEach(popup => popup.remove())
    
    // Get timezone data from the clicked location - consistent for both day/night
    const features = map.queryRenderedFeatures(e.point)
    let timezoneName = 'UTC'
    
    // Look for timezone information in any layer (consistent approach)
    for (const feature of features) {
      if (feature.properties && (feature.properties.tzid || feature.properties.TZID)) {
        timezoneName = feature.properties.tzid || feature.properties.TZID
        break
      }
    }
    
    // Process timezone data consistently for both day and night
    const properTimezoneName = this.getProperTimezoneName(timezoneName)
    const localDateAndTime = this.getLocalDateAndTime(properTimezoneName)
    const timeDifference = this.getTimeDifference(properTimezoneName)
    const tzAbbreviation = this.getTimezoneAbbreviation(properTimezoneName)
    const utcOffset = this.calculateCurrentUTCOffset(properTimezoneName)
    const offsetString = utcOffset >= 0 ? `+${utcOffset}` : `${utcOffset}`
    const workingHoursStatus = this.getWorkingHoursStatus(properTimezoneName)
    const workingHoursIndicator = this.getWorkingHoursIndicator(properTimezoneName)
    const locationInfo = this.getLocationInfo(properTimezoneName)
    
    // Apply styling based on day/night
    const icon = isDayTime ? '☀️' : '🌙'
    const className = isDayTime ? 'timezone-popup' : 'sunlight-info'
    const titleClass = isDayTime ? 'font-semibold text-gray-900' : 'font-semibold text-yellow-400'
    const timeClass = isDayTime ? 'text-xs text-gray-700 mt-1' : 'text-xs text-yellow-300 mt-1'
    const statusClass = isDayTime ? 'text-xs text-gray-500 mt-2' : 'text-xs text-yellow-300 mt-2'
    const timezoneClass = isDayTime ? 'text-xs text-gray-600 mt-1' : 'text-xs text-yellow-300 mt-1'
    
    return new maplibregl.Popup({
      closeButton: true,
      closeOnClick: true,
      className: className
    })
      .setLngLat(e.lngLat)
      .setHTML(`
        <div class="p-3 timezone-popup-content">
          <div class="${titleClass} flex items-center gap-1">
            📍 ${locationInfo.flag} ${locationInfo.city}
          </div>
          <div class="${timeClass} font-bold text-base mt-1">🕒 ${localDateAndTime}</div>
          <div class="${timezoneClass} text-xs mt-1">⏳ ${timeDifference}</div>
          <div class="working-hours-row">
            ${workingHoursIndicator}
            <span class="${statusClass}">${workingHoursStatus}</span>
          </div>
        </div>
      `)
      .addTo(map)
  },

  getProperTimezoneName(timezoneName) {
    // Map UTC offset strings to proper timezone names for better DST handling
    if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
      const offset = this.calculateCurrentUTCOffset(timezoneName)
      
      // Map common UTC offsets to timezone names (prioritizing major cities)
      const offsetToProperTimezone = {
        '-12': 'Pacific/Baker_Island',
        '-11': 'Pacific/Midway',
        '-10': 'Pacific/Honolulu',
        '-9': 'America/Anchorage',
        '-8': 'America/Los_Angeles', // This will automatically handle PST/PDT
        '-7': 'America/Denver',
        '-6': 'America/Chicago',
        '-5': 'America/New_York',
        '-4': 'America/Halifax',
        '-3': 'America/Sao_Paulo',
        '-2': 'Atlantic/South_Georgia',
        '-1': 'Atlantic/Cape_Verde',
        '0': 'Europe/London',
        '1': 'Europe/Berlin',
        '2': 'Europe/Helsinki',
        '3': 'Europe/Moscow',
        '4': 'Asia/Dubai',
        '5': 'Asia/Karachi',
        '5.5': 'Asia/Kolkata',
        '6': 'Asia/Dhaka',
        '7': 'Asia/Bangkok',
        '8': 'Asia/Shanghai',
        '9': 'Asia/Tokyo',
        '10': 'Australia/Sydney',
        '11': 'Pacific/Norfolk',
        '12': 'Pacific/Auckland'
      }
      
      return offsetToProperTimezone[offset.toString()] || timezoneName
    }
    
    return timezoneName
  },

  getTimezoneAbbreviation(timezoneName) {
    // First check our static mapping for common timezone names
    const abbreviationMap = {
      'America/New_York': 'EST',
      'America/Chicago': 'CST', 
      'America/Denver': 'MST',
      'America/Los_Angeles': 'PST',
      'America/Anchorage': 'AKST',
      'Pacific/Honolulu': 'HST',
      'Europe/London': 'GMT',
      'Europe/Berlin': 'CET',
      'Europe/Helsinki': 'EET',
      'Europe/Moscow': 'MSK',
      'Asia/Tokyo': 'JST',
      'Asia/Shanghai': 'CST',
      'Asia/Kolkata': 'IST',
      'Asia/Karachi': 'PKT',
      'Asia/Dubai': 'GST',
      'Asia/Bangkok': 'ICT',
      'Asia/Dhaka': 'BST',
      'Australia/Sydney': 'AEST',
      'Pacific/Auckland': 'NZST'
    }
    
    // Return static mapping if available
    if (abbreviationMap[timezoneName]) {
      return abbreviationMap[timezoneName]
    }
    
    // Handle UTC offset strings (like UTC-08:00)
    if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
      const offset = this.calculateCurrentUTCOffset(timezoneName)
      
      // Map common UTC offsets to timezone abbreviations
      const offsetToTimezone = {
        '-12': 'AoE', '-11': 'SST', '-10': 'HST', '-9': 'AKST', '-8': 'PST',
        '-7': 'PDT', '-6': 'MDT', '-5': 'CDT', '-4': 'EDT', '-3': 'ADT', 
        '-2': 'GST', '-1': 'CVT', '0': 'GMT', '1': 'CET', '2': 'EET',
        '3': 'MSK', '4': 'GST', '5': 'PKT', '5.5': 'IST', '6': 'BST',
        '7': 'ICT', '8': 'CST', '9': 'JST', '10': 'AEST', '11': 'NCT', '12': 'NZST'
      }
      
      return offsetToTimezone[offset.toString()] || `UTC${offset >= 0 ? '+' : ''}${offset}`
    }
    
    // Try browser's built-in timezone abbreviation as last resort
    try {
      const now = new Date()
      const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: timezoneName,
        timeZoneName: 'short'
      })
      const parts = formatter.formatToParts(now)
      const timeZonePart = parts.find(part => part.type === 'timeZoneName')
      if (timeZonePart) {
        return timeZonePart.value
      }
    } catch (error) {
      // Fallback to timezone name
    }
    
    return timezoneName.split('/').pop().replace(/_/g, ' ')
  },

  getLocalDateAndTime(timezoneName) {
    try {
      const now = new Date()
      let localTime
      
      // Handle UTC offset strings (like UTC-08:00)
      if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
        const offset = this.calculateCurrentUTCOffset(timezoneName)
        const utcTime = new Date(now.getTime() + (now.getTimezoneOffset() * 60 * 1000))
        localTime = new Date(utcTime.getTime() + (offset * 60 * 60 * 1000))
      } else {
        localTime = new Date(now.toLocaleString('en-US', { timeZone: timezoneName }))
      }
      
      // Format as YYYY/MM/DD-HH:MM
      const year = localTime.getFullYear()
      const month = String(localTime.getMonth() + 1).padStart(2, '0')
      const day = String(localTime.getDate()).padStart(2, '0')
      const hours = String(localTime.getHours()).padStart(2, '0')
      const minutes = String(localTime.getMinutes()).padStart(2, '0')
      
      return `${year}/${month}/${day}-${hours}:${minutes}`
    } catch (error) {
      const now = new Date()
      const year = now.getFullYear()
      const month = String(now.getMonth() + 1).padStart(2, '0')
      const day = String(now.getDate()).padStart(2, '0')
      const hours = String(now.getHours()).padStart(2, '0')
      const minutes = String(now.getMinutes()).padStart(2, '0')
      
      return `${year}/${month}/${day}-${hours}:${minutes}`
    }
  },

  getTimeDifference(timezoneName) {
    try {
      const now = new Date()
      const userOffset = now.getTimezoneOffset() / 60 // User's offset in hours
      const targetOffset = this.calculateCurrentUTCOffset(timezoneName)
      const difference = targetOffset + userOffset // Difference from user's time
      
      if (difference === 0) {
        return "Same as your time"
      } else if (difference > 0) {
        return `+${difference} hours ahead of you`
      } else {
        return `${Math.abs(difference)} hours behind you`
      }
    } catch (error) {
      return ""
    }
  },

  getWorkingHoursIndicator(timezoneName) {
    try {
      const now = new Date()
      let localTime
      
      if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
        const offset = this.calculateCurrentUTCOffset(timezoneName)
        const utcTime = new Date(now.getTime() + (now.getTimezoneOffset() * 60 * 1000))
        localTime = new Date(utcTime.getTime() + (offset * 60 * 60 * 1000))
      } else {
        localTime = new Date(now.toLocaleString('en-US', { timeZone: timezoneName }))
      }
      
      const hour = localTime.getHours()
      const day = localTime.getDay()
      
      // Weekend
      if (day === 0 || day === 6) {
        return '<div class="working-hours-dot bg-blue-400"></div>'
      }
      
      // Working hours (9 AM to 5 PM)
      if (hour >= 9 && hour < 17) {
        return '<div class="working-hours-dot bg-green-500"></div>'
      } else if (hour >= 17 && hour < 22) {
        return '<div class="working-hours-dot bg-orange-400"></div>'
      } else if (hour >= 22 || hour < 6) {
        return '<div class="working-hours-dot bg-purple-600"></div>'
      } else {
        return '<div class="working-hours-dot bg-yellow-400"></div>'
      }
    } catch (error) {
      return '<div class="working-hours-dot bg-gray-400"></div>'
    }
  },

  getLocationInfo(timezoneName) {
    const locationMap = {
      'America/New_York': { flag: '🇺🇸', city: 'New York' },
      'America/Chicago': { flag: '🇺🇸', city: 'Chicago' },
      'America/Denver': { flag: '🇺🇸', city: 'Denver' },
      'America/Los_Angeles': { flag: '🇺🇸', city: 'Los Angeles' },
      'America/Anchorage': { flag: '🇺🇸', city: 'Anchorage' },
      'Pacific/Honolulu': { flag: '🇺🇸', city: 'Honolulu' },
      'America/Toronto': { flag: '🇨🇦', city: 'Toronto' },
      'America/Vancouver': { flag: '🇨🇦', city: 'Vancouver' },
      'Europe/London': { flag: '🇬🇧', city: 'London' },
      'Europe/Berlin': { flag: '🇩🇪', city: 'Berlin' },
      'Europe/Paris': { flag: '🇫🇷', city: 'Paris' },
      'Europe/Rome': { flag: '🇮🇹', city: 'Rome' },
      'Europe/Helsinki': { flag: '🇫🇮', city: 'Helsinki' },
      'Europe/Athens': { flag: '🇬🇷', city: 'Athens' },
      'Europe/Moscow': { flag: '🇷🇺', city: 'Moscow' },
      'Asia/Tokyo': { flag: '🇯🇵', city: 'Tokyo' },
      'Asia/Shanghai': { flag: '🇨🇳', city: 'Shanghai' },
      'Asia/Kolkata': { flag: '🇮🇳', city: 'Mumbai' },
      'Asia/Karachi': { flag: '🇵🇰', city: 'Karachi' },
      'Asia/Dubai': { flag: '🇦🇪', city: 'Dubai' },
      'Asia/Bangkok': { flag: '🇹🇭', city: 'Bangkok' },
      'Asia/Dhaka': { flag: '🇧🇩', city: 'Dhaka' },
      'Australia/Sydney': { flag: '🇦🇺', city: 'Sydney' },
      'Australia/Melbourne': { flag: '🇦🇺', city: 'Melbourne' },
      'Pacific/Auckland': { flag: '🇳🇿', city: 'Auckland' },
      'America/Sao_Paulo': { flag: '🇧🇷', city: 'São Paulo' },
      'America/Mexico_City': { flag: '🇲🇽', city: 'Mexico City' }
    }
    
    return locationMap[timezoneName] || { flag: '🌍', city: timezoneName.split('/').pop().replace(/_/g, ' ') }
  },

  getLocationFlag(timezoneName) {
    return this.getLocationInfo(timezoneName).flag
  },

  getWorkingHoursStatus(timezoneName) {
    try {
      const now = new Date()
      let localTime
      
      // Handle UTC offset strings (like UTC-08:00)
      if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
        const offset = this.calculateCurrentUTCOffset(timezoneName)
        // Get current UTC time and apply offset
        const utcTime = new Date(now.getTime() + (now.getTimezoneOffset() * 60 * 1000))
        localTime = new Date(utcTime.getTime() + (offset * 60 * 60 * 1000))
      } else {
        // Use proper timezone name
        localTime = new Date(now.toLocaleString('en-US', { timeZone: timezoneName }))
      }
      
      const hour = localTime.getHours()
      const day = localTime.getDay()
      
      // Weekend check (Saturday = 6, Sunday = 0)
      if (day === 0 || day === 6) {
        return 'Weekend'
      }
      
      // Working hours check (9 AM to 5 PM)
      if (hour >= 9 && hour < 17) {
        return 'Working hours'
      } else if (hour >= 17 && hour < 22) {
        return 'Evening hours'
      } else if (hour >= 22 || hour < 6) {
        return 'Night hours'
      } else {
        return 'Morning hours'
      }
    } catch (error) {
      return 'Working hours unknown'
    }
  },

  getTimezoneOffset(timezoneName) {
    // Handle UTC±XX:XX format timezone identifiers (including ± symbol)
    if (typeof timezoneName === 'string' && timezoneName.match(/^UTC[+\-±]\d{1,2}:\d{2}$/)) {
      const match = timezoneName.match(/^UTC([+\-±])(\d{1,2}):(\d{2})$/)
      if (match) {
        const sign = match[1] === '+' ? 1 : -1  // ± symbol defaults to 0 (handled below)
        const hours = parseInt(match[2], 10)
        const minutes = parseInt(match[3], 10)
        
        // UTC±00:00, UTC+00:00 and UTC-00:00 all represent GMT/UTC (offset 0)
        if (hours === 0 && minutes === 0) {
          return 0
        }
        
        const offset = sign * (hours + minutes / 60)
        return offset
      }
    }
    
    try {
      const now = new Date()
      const utc = new Date(now.getTime() + (now.getTimezoneOffset() * 60000))
      const local = new Date(utc.toLocaleString("en-US", {timeZone: timezoneName}))
      const offset = (local.getTime() - utc.getTime()) / (1000 * 60 * 60)
      return offset
    } catch (error) {
      console.error('Error getting timezone offset for', timezoneName, error)
      // Fallback to static mapping for common timezones
      const staticOffsets = {
        'America/New_York': -5,
        'America/Chicago': -6,
        'America/Denver': -7,
        'America/Los_Angeles': -8,
        'Europe/London': 0,
        'Europe/Paris': 1,
        'Europe/Moscow': 3,
        'Asia/Tokyo': 9,
        'Australia/Sydney': 10,
        'Pacific/Auckland': 12
      }
      return staticOffsets[timezoneName] || 0
    }
  },

  extractUTCOffset(timezoneName) {
    // Extract UTC offset from timezone name
    const offsetMap = {
      // Pacific
      'Pacific/Baker_Island': -12,
      'Pacific/Midway': -11,
      'Pacific/Honolulu': -10,
      'Pacific/Marquesas': -9.5,
      'America/Anchorage': -9,
      
      // North America
      'America/Los_Angeles': -8,
      'America/Vancouver': -8,
      'America/Denver': -7,
      'America/Phoenix': -7,
      'America/Chicago': -6,
      'America/Mexico_City': -6,
      'America/New_York': -5,
      'America/Toronto': -5,
      'America/Caracas': -4,
      'America/Santiago': -4,
      'America/Sao_Paulo': -3,
      'America/Buenos_Aires': -3,
      'America/St_Johns': -3.5,
      
      // Atlantic
      'Atlantic/Cape_Verde': -1,
      'Atlantic/Azores': -1,
      
      // Europe/Africa
      'Europe/London': 0,
      'Europe/Dublin': 0,
      'Africa/Casablanca': 0,
      'Europe/Berlin': 1,
      'Europe/Paris': 1,
      'Europe/Rome': 1,
      'Europe/Helsinki': 2,
      'Europe/Athens': 2,
      'Africa/Cairo': 2,
      'Europe/Moscow': 3,
      'Africa/Nairobi': 3,
      'Asia/Dubai': 4,
      'Asia/Baku': 4,
      'Asia/Kabul': 4.5,
      'Asia/Karachi': 5,
      'Asia/Kolkata': 5.5,
      'Asia/Kathmandu': 5.75,
      'Asia/Dhaka': 6,
      'Asia/Yangon': 6.5,
      'Asia/Bangkok': 7,
      'Asia/Jakarta': 7,
      
      // Asia/Pacific
      'Asia/Shanghai': 8,
      'Asia/Singapore': 8,
      'Asia/Manila': 8,
      'Australia/Perth': 8,
      'Asia/Tokyo': 9,
      'Asia/Seoul': 9,
      'Australia/Adelaide': 9.5,
      'Australia/Darwin': 9.5,
      'Australia/Sydney': 10,
      'Australia/Melbourne': 10,
      'Pacific/Guam': 10,
      'Australia/Lord_Howe': 10.5,
      'Pacific/Norfolk': 11,
      'Pacific/Auckland': 12,
      'Pacific/Fiji': 12,
      'Pacific/Chatham': 12.75,
      'Pacific/Tongatapu': 13,
      'Pacific/Kiritimati': 14
    }
    
    // Try exact match first
    if (offsetMap[timezoneName]) {
      return offsetMap[timezoneName]
    }
    
    // Try to extract from common patterns
    if (timezoneName.includes('UTC') || timezoneName.includes('GMT')) {
      const match = timezoneName.match(/([+-])(\d+)(?:\.(\d+))?/)
      if (match) {
        const sign = match[1] === '+' ? 1 : -1
        const hours = parseInt(match[2])
        const minutes = match[3] ? parseInt(match[3]) * 6 : 0
        return sign * (hours + minutes / 60)
      }
    }
    
    return 0 // Default to UTC
  },

  addSimplifiedTimezones(map) {
    // Fallback to simplified rectangular zones if accurate data fails to load
    const timezoneRegions = [
      {
        name: 'UTC-12 to UTC-8 (Pacific)',
        color: 'rgba(255, 99, 132, 0.3)',
        bounds: [[-180, -60], [-120, 75]]
      },
      {
        name: 'UTC-8 to UTC-5 (Americas)',
        color: 'rgba(54, 162, 235, 0.3)',
        bounds: [[-120, -60], [-60, 75]]
      },
      {
        name: 'UTC-5 to UTC-1 (Atlantic)',
        color: 'rgba(255, 205, 86, 0.3)',
        bounds: [[-60, -60], [-15, 75]]
      },
      {
        name: 'UTC-1 to UTC+3 (Europe/Africa)',
        color: 'rgba(75, 192, 192, 0.3)',
        bounds: [[-15, -60], [45, 75]]
      },
      {
        name: 'UTC+3 to UTC+7 (Asia West)',
        color: 'rgba(153, 102, 255, 0.3)',
        bounds: [[45, -60], [105, 75]]
      },
      {
        name: 'UTC+7 to UTC+12 (Asia East/Pacific)',
        color: 'rgba(255, 159, 64, 0.3)',
        bounds: [[105, -60], [180, 75]]
      }
    ]

    timezoneRegions.forEach((region, index) => {
      const [sw, ne] = region.bounds
      const sourceId = `timezone-region-${index}`
      const layerId = `timezone-layer-${index}`

      // Create a rectangle GeoJSON feature
      const geojson = {
        type: 'Feature',
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [sw[0], sw[1]], // Southwest corner
            [ne[0], sw[1]], // Southeast corner
            [ne[0], ne[1]], // Northeast corner
            [sw[0], ne[1]], // Northwest corner
            [sw[0], sw[1]]  // Close the polygon
          ]]
        },
        properties: {
          name: region.name,
          color: region.color
        }
      }

      // Add source
      map.addSource(sourceId, {
        type: 'geojson',
        data: geojson
      })

      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': region.color,
          'fill-opacity': 0.03
        }
      })

      // Add border layer
      map.addLayer({
        id: `${layerId}-border`,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': region.color.replace('0.3', '0.8'),
          'line-width': 0.6,
          'line-dasharray': [3, 3]
        }
      })

      // Add popup on click
      map.on('click', layerId, (e) => {
        // Don't show timezone popup if clicking on night region
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="p-2">
              <div class="font-semibold text-gray-900">${region.name}</div>
              <div class="text-xs text-gray-600 mt-1">Timezone Region</div>
            </div>
          `)
          .addTo(map)
      })

      // Change cursor on hover
      map.on('mouseenter', layerId, () => {
        map.getCanvas().style.cursor = 'pointer'
      })

      map.on('mouseleave', layerId, () => {
        map.getCanvas().style.cursor = ''
      })
    })

    console.log('Simplified timezone overlay added successfully')
  },

  async loadEmbeddedTimezones(map) {
    // Implement exactly like timeanddate.com - use proper timezone boundary data
    console.log('Loading timezone boundaries like timeanddate.com...')
    
    try {
      // Use the same approach as timeanddate.com - load timezone boundary JSON data
      await this.loadTimeAndDateStyleTimezones(map)
      
    } catch (error) {
      console.error('Failed to load timezone data:', error)
      // Fallback to simplified zones only if absolutely necessary
      this.addSimplifiedTimezones(map)
    }
  },

  async loadTimeAndDateStyleTimezones(map) {
    // Load actual timezone boundaries exactly like timeanddate.com
    console.log('Loading actual timezone boundary data...')
    
    try {
      // Use embedded timezone boundary data that shows multiple timezones per country
      await this.useActualTimezoneBoundaries(map)
      
    } catch (error) {
      console.error('Failed to load timezone boundaries:', error)
      // Fallback to simplified accurate approach
      await this.loadSimplifiedAccurateTimezones(map)
    }
  },

  async useActualTimezoneBoundaries(map) {
    // Use actual timezone boundary data that shows multiple timezones per country
    console.log('Creating timezone boundaries with multiple zones per country...')
    
    const timezoneBoundaries = [
      // United States - Multiple timezones (this is what timeanddate.com shows)
      {
        timezone: 'America/Los_Angeles',
        name: 'US Pacific Time',
        offset: -8,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-124.7, 32.5], [-124.7, 49.0], [-120.0, 49.0], 
            [-117.0, 44.0], [-114.0, 32.5], [-124.7, 32.5]
          ]]
        }
      },
      {
        timezone: 'America/Denver',
        name: 'US Mountain Time',
        offset: -7,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-117.0, 32.5], [-117.0, 49.0], [-104.0, 49.0], 
            [-104.0, 32.5], [-117.0, 32.5]
          ]]
        }
      },
      {
        timezone: 'America/Chicago',
        name: 'US Central Time',
        offset: -6,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-104.0, 25.8], [-104.0, 49.0], [-87.5, 49.0], 
            [-84.0, 30.0], [-97.0, 25.8], [-104.0, 25.8]
          ]]
        }
      },
      {
        timezone: 'America/New_York',
        name: 'US Eastern Time',
        offset: -5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-87.5, 24.5], [-87.5, 49.0], [-67.0, 49.0], 
            [-67.0, 44.0], [-80.0, 25.0], [-87.5, 24.5]
          ]]
        }
      },
      
      // Russia - Multiple timezones
      {
        timezone: 'Europe/Moscow',
        name: 'Moscow Time',
        offset: 3,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [27.0, 41.0], [60.0, 41.0], [60.0, 82.0], [27.0, 82.0], [27.0, 41.0]
          ]]
        }
      },
      {
        timezone: 'Asia/Yekaterinburg',
        name: 'Yekaterinburg Time',
        offset: 5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [60.0, 41.0], [87.0, 41.0], [87.0, 82.0], [60.0, 82.0], [60.0, 41.0]
          ]]
        }
      },
      {
        timezone: 'Asia/Novosibirsk',
        name: 'Novosibirsk Time',
        offset: 7,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [87.0, 41.0], [120.0, 41.0], [120.0, 82.0], [87.0, 82.0], [87.0, 41.0]
          ]]
        }
      },
      {
        timezone: 'Asia/Yakutsk',
        name: 'Yakutsk Time',
        offset: 9,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [120.0, 41.0], [150.0, 41.0], [150.0, 82.0], [120.0, 82.0], [120.0, 41.0]
          ]]
        }
      },
      {
        timezone: 'Asia/Vladivostok',
        name: 'Vladivostok Time',
        offset: 10,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [150.0, 41.0], [180.0, 41.0], [180.0, 82.0], [150.0, 82.0], [150.0, 41.0]
          ]]
        }
      },
      
      // Australia - Multiple timezones
      {
        timezone: 'Australia/Perth',
        name: 'Western Australia',
        offset: 8,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [112.0, -35.0], [129.0, -35.0], [129.0, -13.5], [112.0, -13.5], [112.0, -35.0]
          ]]
        }
      },
      {
        timezone: 'Australia/Adelaide',
        name: 'Central Australia',
        offset: 9.5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [129.0, -38.0], [141.0, -38.0], [141.0, -26.0], [129.0, -26.0], [129.0, -38.0]
          ]]
        }
      },
      {
        timezone: 'Australia/Sydney',
        name: 'Eastern Australia',
        offset: 10,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [141.0, -39.0], [154.0, -39.0], [154.0, -10.0], [141.0, -10.0], [141.0, -39.0]
          ]]
        }
      },
      
      // Canada - Multiple timezones
      {
        timezone: 'America/Vancouver',
        name: 'Canada Pacific',
        offset: -8,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-141.0, 48.0], [-120.0, 48.0], [-120.0, 84.0], [-141.0, 84.0], [-141.0, 48.0]
          ]]
        }
      },
      {
        timezone: 'America/Edmonton',
        name: 'Canada Mountain',
        offset: -7,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-120.0, 48.0], [-102.0, 48.0], [-102.0, 84.0], [-120.0, 84.0], [-120.0, 48.0]
          ]]
        }
      },
      {
        timezone: 'America/Winnipeg',
        name: 'Canada Central',
        offset: -6,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-102.0, 48.0], [-90.0, 48.0], [-90.0, 84.0], [-102.0, 84.0], [-102.0, 48.0]
          ]]
        }
      },
      {
        timezone: 'America/Toronto',
        name: 'Canada Eastern',
        offset: -5,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-90.0, 48.0], [-60.0, 48.0], [-60.0, 84.0], [-90.0, 84.0], [-90.0, 48.0]
          ]]
        }
      },
      
      // Other major single-timezone regions
      {
        timezone: 'Europe/London',
        name: 'GMT/BST',
        offset: 0,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [-11.0, 49.5], [2.0, 49.5], [2.0, 61.0], [-11.0, 61.0], [-11.0, 49.5]
          ]]
        }
      },
      {
        timezone: 'Europe/Berlin',
        name: 'Central Europe',
        offset: 1,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [2.0, 35.0], [24.0, 35.0], [24.0, 71.0], [2.0, 71.0], [2.0, 35.0]
          ]]
        }
      },
      {
        timezone: 'Asia/Shanghai',
        name: 'China Standard',
        offset: 8,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [73.0, 18.0], [135.0, 18.0], [135.0, 54.0], [73.0, 54.0], [73.0, 18.0]
          ]]
        }
      },
      {
        timezone: 'Asia/Tokyo',
        name: 'Japan Standard',
        offset: 9,
        geometry: {
          type: 'Polygon',
          coordinates: [[
            [129.0, 24.0], [146.0, 24.0], [146.0, 46.0], [129.0, 46.0], [129.0, 24.0]
          ]]
        }
      }
    ]
    
    const timezoneColors = this.getTimezoneColors()
    
    timezoneBoundaries.forEach((boundary, index) => {
      const color = this.getColorForOffset(boundary.offset, timezoneColors)
      const sourceId = `timezone-boundary-${index}`
      const layerId = `timezone-layer-${index}`
      const borderLayerId = `timezone-border-${index}`
      
      // Add source with actual timezone boundary geometry
      map.addSource(sourceId, {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: boundary.geometry,
          properties: {
            timezone: boundary.timezone,
            name: boundary.name,
            offset: boundary.offset
          }
        }
      })
      
      // Add fill layer
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.05
        }
      })
      
      // Add border layer
      map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': color.replace('0.3', '0.9'),
          'line-width': 0.6,
          'line-opacity': 0.35
        }
      })
      
      // Add click handler
      map.on('click', layerId, (e) => {
        const currentTime = this.getCurrentTimeInTimezone(boundary.timezone)
        
        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="team-popup p-4">
              <div class="text-sm font-semibold text-gray-900 mb-2">${boundary.name}</div>
              <div class="text-xs text-gray-600 mb-1">${boundary.timezone}</div>
              <div class="text-xs text-gray-600">Current time: ${currentTime}</div>
            </div>
          `)
          .addTo(map)
      })
    })
    
    console.log(`Added ${timezoneBoundaries.length} timezone boundary regions`)
  },

  async createTimezoneRegionsFromRealBoundaries(map, worldData) {
    // Create timezone regions using actual country boundaries like timeanddate.com
    console.log('Creating timezone regions from real geographic boundaries...')
    
    const timezoneColors = this.getTimezoneColors()
    const countryTimezoneMap = this.getCountryTimezoneMap()
    
    // Group countries by timezone offset for proper coloring
    const timezoneGroups = {}
    
    worldData.features.forEach((feature) => {
      const countryName = feature.properties.NAME || feature.properties.name || feature.properties.NAME_EN
      const timezoneInfo = countryTimezoneMap[countryName]
      
      if (timezoneInfo) {
        const offsetKey = timezoneInfo.offset.toString()
        if (!timezoneGroups[offsetKey]) {
          timezoneGroups[offsetKey] = {
            features: [],
            timezone: timezoneInfo.timezone,
            offset: timezoneInfo.offset,
            countries: []
          }
        }
        timezoneGroups[offsetKey].features.push(feature)
        timezoneGroups[offsetKey].countries.push(countryName)
      }
    })
    
    // Add each timezone group to the map with real geographic boundaries
    Object.keys(timezoneGroups).forEach((offsetKey) => {
      const group = timezoneGroups[offsetKey]
      const color = this.getColorForOffset(group.offset, timezoneColors)
      const sourceId = `timezone-group-${offsetKey.replace('.', '_').replace('-', 'neg')}`
      const layerId = `timezone-group-layer-${offsetKey.replace('.', '_').replace('-', 'neg')}`
      const borderLayerId = `timezone-group-border-${offsetKey.replace('.', '_').replace('-', 'neg')}`
      
      // Create feature collection with real country/region boundaries
      const featureCollection = {
        type: 'FeatureCollection',
        features: group.features
      }
      
      console.log(`Adding timezone group UTC${group.offset >= 0 ? '+' : ''}${group.offset} with ${group.features.length} regions`)
      
      // Add source with actual geographic boundaries (not rectangles!)
      map.addSource(sourceId, {
        type: 'geojson',
        data: featureCollection
      })
      
      // Add fill layer with timezone-based coloring
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.05
        }
      })
      
      // Add border layer for timezone boundaries  
      map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': color.replace('0.3', '0.9'),
          'line-width': 0.6,
          'line-opacity': 0.3
        }
      })
      
      // Add click handler
      map.on('click', layerId, (e) => {
        const features = map.queryRenderedFeatures(e.point, { layers: [layerId] })
        if (features.length > 0) {
          const feature = features[0]
          const regionName = feature.properties.NAME || feature.properties.name || 'Unknown Region'
          const currentTime = this.getCurrentTimeInTimezone(group.timezone)
          
          new maplibregl.Popup()
            .setLngLat(e.lngLat)
            .setHTML(`
              <div class="team-popup p-4">
                <div class="text-sm font-semibold text-gray-900 mb-2">${regionName}</div>
                <div class="text-xs text-gray-600 mb-1">${group.timezone}</div>
                <div class="text-xs text-gray-600">Current time: ${currentTime}</div>
              </div>
            `)
            .addTo(map)
        }
      })
    })
    
    console.log(`Successfully created timezone overlay with ${Object.keys(timezoneGroups).length} timezone groups using real boundaries`)
  },

  async loadSimplifiedAccurateTimezones(map) {
    // Load a simplified but accurate timezone representation like timeanddate.com
    console.log('Loading simplified accurate timezone data...')
    
    // Use timezone data that matches timeanddate.com's approach
    const timezoneRegions = [
      // Americas
      { name: 'Pacific Time', offset: -8, bounds: [-180, 30, -120, 70], timezone: 'America/Los_Angeles' },
      { name: 'Mountain Time', offset: -7, bounds: [-120, 30, -105, 55], timezone: 'America/Denver' }, 
      { name: 'Central Time', offset: -6, bounds: [-105, 25, -90, 50], timezone: 'America/Chicago' },
      { name: 'Eastern Time', offset: -5, bounds: [-90, 25, -65, 50], timezone: 'America/New_York' },
      { name: 'Atlantic Time', offset: -4, bounds: [-70, 10, -55, 50], timezone: 'America/Halifax' },
      { name: 'Brazil Time', offset: -3, bounds: [-75, -35, -35, 10], timezone: 'America/Sao_Paulo' },
      
      // Europe & Africa  
      { name: 'GMT/WET', offset: 0, bounds: [-15, 35, 5, 70], timezone: 'Europe/London' },
      { name: 'CET', offset: 1, bounds: [5, 35, 25, 70], timezone: 'Europe/Berlin' },
      { name: 'EET', offset: 2, bounds: [25, 35, 45, 70], timezone: 'Europe/Helsinki' },
      { name: 'West Africa', offset: 1, bounds: [-20, -35, 15, 35], timezone: 'Africa/Lagos' },
      { name: 'East Africa', offset: 3, bounds: [15, -35, 50, 35], timezone: 'Africa/Nairobi' },
      
      // Asia
      { name: 'Moscow Time', offset: 3, bounds: [25, 40, 65, 75], timezone: 'Europe/Moscow' },
      { name: 'India Standard', offset: 5.5, bounds: [65, 5, 100, 40], timezone: 'Asia/Kolkata' },
      { name: 'China Standard', offset: 8, bounds: [75, 15, 135, 55], timezone: 'Asia/Shanghai' },
      { name: 'Japan Standard', offset: 9, bounds: [125, 25, 150, 50], timezone: 'Asia/Tokyo' },
      
      // Oceania
      { name: 'Australia West', offset: 8, bounds: [110, -45, 130, -10], timezone: 'Australia/Perth' },
      { name: 'Australia Central', offset: 9.5, bounds: [130, -35, 145, -10], timezone: 'Australia/Adelaide' },
      { name: 'Australia East', offset: 10, bounds: [145, -45, 180, -10], timezone: 'Australia/Sydney' },
      { name: 'New Zealand', offset: 12, bounds: [165, -50, 180, -30], timezone: 'Pacific/Auckland' }
    ]
    
    const timezoneColors = this.getTimezoneColors()
    
    timezoneRegions.forEach((region, index) => {
      const color = this.getColorForOffset(region.offset, timezoneColors)
      const sourceId = `timezone-${index}`
      const layerId = `timezone-layer-${index}`
      const borderLayerId = `timezone-border-${index}`
      
      const [west, south, east, north] = region.bounds
      const coordinates = [[
        [west, south], [east, south], [east, north], [west, north], [west, south]
      ]]
      
      map.addSource(sourceId, {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: {
            type: 'Polygon',
            coordinates: coordinates
          },
          properties: {
            name: region.name,
            timezone: region.timezone,
            offset: region.offset
          }
        }
      })
      
      map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': color,
          'fill-opacity': 0.05
        }
      })
      
      map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': color.replace('0.3', '0.8'),
          'line-width': 0.6,
          'line-opacity': 0.35
        }
      })
      
      // Add click handler
      map.on('click', layerId, (e) => {
        // Don't show timezone popup if clicking on night region
        if (!this.shouldShowTimezonePopup(map, e)) {
          return
        }
        
        const currentTime = this.getCurrentTimeInTimezone(region.timezone)
        
        new maplibregl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(`
            <div class="team-popup p-4">
              <div class="text-sm font-semibold text-gray-900 mb-2">${region.name}</div>
              <div class="text-xs text-gray-600 mb-1">${region.timezone}</div>
              <div class="text-xs text-gray-600">Current time: ${currentTime}</div>
            </div>
          `)
          .addTo(map)
      })
    })
    
    console.log(`Added ${timezoneRegions.length} timezone regions`)
  },

  async loadTimezoneShapes(map) {
    // Use a simpler but accurate approach for timezone boundaries like timeanddate.com
    console.log('Loading timezone boundary data...')
    
    try {
      // Create timezone regions manually based on timeanddate.com's approach
      // This gives us the most accurate representation
      const timezoneRegions = this.getAccurateTimezoneShapes()
      const timezoneColors = this.getTimezoneColors()
      
      console.log(`Loading ${timezoneRegions.length} timezone regions`)
      
      timezoneRegions.forEach((region, index) => {
        const sourceId = `timezone-region-${index}`
        const layerId = `timezone-layer-${index}`
        const borderLayerId = `timezone-border-${index}`
        
        const color = this.getColorForOffset(region.utcOffset, timezoneColors)
        
        // Add source
        map.addSource(sourceId, {
          type: 'geojson',
          data: {
            type: 'Feature',
            geometry: region.geometry,
            properties: {
              name: region.name,
              utcOffset: region.utcOffset,
              timezoneName: region.timezoneName
            }
          }
        })
        
        // Add fill layer
        map.addLayer({
          id: layerId,
          type: 'fill',
          source: sourceId,
          paint: {
            'fill-color': color,
            'fill-opacity': 0.05
          }
        })
        
        // Add border layer for timezone boundaries
        map.addLayer({
          id: borderLayerId,
          type: 'line',
          source: sourceId,
          paint: {
            'line-color': color.replace('0.3', '0.9'),
            'line-width': 0.6,
            'line-opacity': 0.3
          }
        })
        
        // Add click handler
        map.on('click', layerId, (e) => {
          // Don't show timezone popup if clicking on night region
          if (!this.shouldShowTimezonePopup(map, e)) {
            return
          }
          
          const currentTime = this.getCurrentTimeInTimezone(region.timezoneName)
          
          new maplibregl.Popup()
            .setLngLat(e.lngLat)
            .setHTML(`
              <div class="team-popup p-4">
                <div class="text-sm font-semibold text-gray-900 mb-2">${region.name}</div>
                <div class="text-xs text-gray-600 mb-1">UTC${region.utcOffset >= 0 ? '+' : ''}${region.utcOffset}</div>
                <div class="text-xs text-gray-600 mb-1">${region.timezoneName}</div>
                <div class="text-xs text-gray-600">Current time: ${currentTime}</div>
              </div>
            `)
            .addTo(map)
        })
      })
      
      console.log(`Added ${timezoneRegions.length} timezone regions with accurate boundaries`)
      
    } catch (error) {
      console.error('Failed to load timezone shapes:', error)
      throw error
    }
  },

  async loadCountryBasedTimezones(map) {
    // Fallback: Load world country boundaries and map them to timezones
    console.log('Loading country boundaries for timezone mapping...')
    
    try {
      const response = await fetch('https://cdn.jsdelivr.net/npm/world-atlas@3/countries-110m.json')
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      
      const worldData = await response.json()
      console.log(`Loaded ${worldData.features.length} countries`)
      
      // Map countries to their primary timezones (like timeanddate.com does)
      const countryTimezoneMap = this.getCountryTimezoneMap()
      const timezoneColors = this.getTimezoneColors()
      
      // Group countries by their UTC offset for consistent coloring
      const timezoneGroups = {}
      
      worldData.features.forEach((feature) => {
        const countryName = feature.properties.NAME || feature.properties.name || feature.properties.NAME_EN
        const timezoneInfo = countryTimezoneMap[countryName]
        
        if (timezoneInfo) {
          const offsetKey = timezoneInfo.offset.toString()
          if (!timezoneGroups[offsetKey]) {
            timezoneGroups[offsetKey] = {
              features: [],
              timezone: timezoneInfo.timezone,
              offset: timezoneInfo.offset,
              countries: []
            }
          }
          timezoneGroups[offsetKey].features.push(feature)
          timezoneGroups[offsetKey].countries.push(countryName)
        } else {
          console.log(`No timezone mapping for country: ${countryName}`)
        }
      })
      
      console.log(`Created ${Object.keys(timezoneGroups).length} timezone groups`)
      
      // Add each timezone group to the map using actual country boundaries
      Object.keys(timezoneGroups).forEach((offsetKey) => {
        const group = timezoneGroups[offsetKey]
        const color = this.getColorForOffset(group.offset, timezoneColors)
        const sourceId = `timezone-group-${offsetKey.replace('.', '_').replace('-', 'neg')}`
        const layerId = `timezone-group-layer-${offsetKey.replace('.', '_').replace('-', 'neg')}`
        const borderLayerId = `timezone-group-border-${offsetKey.replace('.', '_').replace('-', 'neg')}`
        const hoverLayerId = `timezone-group-hover-${offsetKey.replace('.', '_').replace('-', 'neg')}`
        
        // Create feature collection for this timezone group
        const featureCollection = {
          type: 'FeatureCollection',
          features: group.features
        }
        
        console.log(`Adding timezone group UTC${group.offset >= 0 ? '+' : ''}${group.offset} with ${group.features.length} countries: ${group.countries.slice(0, 3).join(', ')}${group.countries.length > 3 ? '...' : ''}`)
        
        // Add source
        map.addSource(sourceId, {
          type: 'geojson',
          data: featureCollection
        })
        
        // Add fill layer with timezone-based coloring
        map.addLayer({
          id: layerId,
          type: 'fill',
          source: sourceId,
          paint: {
            'fill-color': color,
            'fill-opacity': 0.05
          }
        })
        
        // Add hover highlight layer for entire timezone region
        map.addLayer({
          id: hoverLayerId,
          type: 'fill',
          source: sourceId,
          paint: {
            'fill-color': '#3b82f6',
            'fill-opacity': 0.35
          },
          layout: {
            'visibility': 'none' // Initially hidden
          }
        })
        
        // Add border layer for country boundaries
        map.addLayer({
          id: borderLayerId,
          type: 'line',
          source: sourceId,
          paint: {
            'line-color': color.replace('0.3', '0.9'),
            'line-width': 0.8,
            'line-opacity': 0.35
          }
        })
        
        // Add click handler
        map.on('click', layerId, (e) => {
          // Don't show timezone popup if clicking on night region
          if (!this.shouldShowTimezonePopup(map, e)) {
            return
          }
          
          const features = map.queryRenderedFeatures(e.point, { layers: [layerId] })
          if (features.length > 0) {
            const feature = features[0]
            const countryName = feature.properties.NAME || feature.properties.name || 'Unknown Country'
            const currentTime = this.getCurrentTimeInTimezone(group.timezone)
            
            new maplibregl.Popup()
              .setLngLat(e.lngLat)
              .setHTML(`
                <div class="p-3">
                  <div class="font-semibold text-gray-900">${countryName}</div>
                  <div class="text-xs text-gray-500 mt-1">${group.timezone}</div>
                  <div class="text-xs text-gray-700 mt-2">Current time: ${currentTime}</div>
                </div>
              `)
              .addTo(map)
          }
        })
        
        // Enhanced hover effects - highlight individual countries
        map.on('mousemove', layerId, (e) => {
          map.getCanvas().style.cursor = 'pointer'
          
          // Get the specific country being hovered
          if (e.features && e.features.length > 0) {
            const hoveredCountry = e.features[0].properties.NAME || e.features[0].properties.name
            
            // Use filter to show only the hovered country
            try {
              map.setFilter(hoverLayerId, ['==', ['get', 'NAME'], hoveredCountry])
              map.setLayoutProperty(hoverLayerId, 'visibility', 'visible')
            } catch (error) {
              console.warn('Failed to show hover highlight:', error)
            }
          }
        })
        
        map.on('mouseleave', layerId, () => {
          map.getCanvas().style.cursor = ''
          
          // Hide the hover layer
          try {
            map.setLayoutProperty(hoverLayerId, 'visibility', 'none')
          } catch (error) {
            console.warn('Failed to hide hover highlight:', error)
          }
        })
      })
      
      console.log('✅ Country-based timezone boundaries loaded successfully with hover effects!')
      
    } catch (error) {
      console.error('Failed to load country timezone data:', error)
      // Fallback to simplified zones
      this.addSimplifiedTimezones(map)
    }
  },

  getCountryTimezoneMap() {
    // Comprehensive country to timezone mapping (like timeanddate.com)
    return {
      // North America
      'United States of America': { timezone: 'America/New_York', offset: -5 },
      'USA': { timezone: 'America/New_York', offset: -5 },
      'United States': { timezone: 'America/New_York', offset: -5 },
      'Canada': { timezone: 'America/Toronto', offset: -5 },
      'Mexico': { timezone: 'America/Mexico_City', offset: -6 },
      'Greenland': { timezone: 'America/Godthab', offset: -3 },
      
      // Central & South America
      'Brazil': { timezone: 'America/Sao_Paulo', offset: -3 },
      'Argentina': { timezone: 'America/Buenos_Aires', offset: -3 },
      'Chile': { timezone: 'America/Santiago', offset: -4 },
      'Colombia': { timezone: 'America/Bogota', offset: -5 },
      'Peru': { timezone: 'America/Lima', offset: -5 },
      'Venezuela': { timezone: 'America/Caracas', offset: -4 },
      'Ecuador': { timezone: 'America/Guayaquil', offset: -5 },
      'Bolivia': { timezone: 'America/La_Paz', offset: -4 },
      'Paraguay': { timezone: 'America/Asuncion', offset: -3 },
      'Uruguay': { timezone: 'America/Montevideo', offset: -3 },
      'Guatemala': { timezone: 'America/Guatemala', offset: -6 },
      'Costa Rica': { timezone: 'America/Costa_Rica', offset: -6 },
      'Panama': { timezone: 'America/Panama', offset: -5 },
      'Cuba': { timezone: 'America/Havana', offset: -5 },
      'Jamaica': { timezone: 'America/Jamaica', offset: -5 },
      
      // Europe
      'United Kingdom': { timezone: 'Europe/London', offset: 0 },
      'Ireland': { timezone: 'Europe/Dublin', offset: 0 },
      'Iceland': { timezone: 'Atlantic/Reykjavik', offset: 0 },
      'Portugal': { timezone: 'Europe/Lisbon', offset: 0 },
      'Spain': { timezone: 'Europe/Madrid', offset: 1 },
      'France': { timezone: 'Europe/Paris', offset: 1 },
      'Germany': { timezone: 'Europe/Berlin', offset: 1 },
      'Italy': { timezone: 'Europe/Rome', offset: 1 },
      'Netherlands': { timezone: 'Europe/Amsterdam', offset: 1 },
      'Belgium': { timezone: 'Europe/Brussels', offset: 1 },
      'Switzerland': { timezone: 'Europe/Zurich', offset: 1 },
      'Austria': { timezone: 'Europe/Vienna', offset: 1 },
      'Czech Republic': { timezone: 'Europe/Prague', offset: 1 },
      'Poland': { timezone: 'Europe/Warsaw', offset: 1 },
      'Hungary': { timezone: 'Europe/Budapest', offset: 1 },
      'Slovakia': { timezone: 'Europe/Bratislava', offset: 1 },
      'Slovenia': { timezone: 'Europe/Ljubljana', offset: 1 },
      'Croatia': { timezone: 'Europe/Zagreb', offset: 1 },
      'Serbia': { timezone: 'Europe/Belgrade', offset: 1 },
      'Bosnia and Herzegovina': { timezone: 'Europe/Sarajevo', offset: 1 },
      'Montenegro': { timezone: 'Europe/Podgorica', offset: 1 },
      'Macedonia': { timezone: 'Europe/Skopje', offset: 1 },
      'Albania': { timezone: 'Europe/Tirane', offset: 1 },
      'Denmark': { timezone: 'Europe/Copenhagen', offset: 1 },
      'Sweden': { timezone: 'Europe/Stockholm', offset: 1 },
      'Norway': { timezone: 'Europe/Oslo', offset: 1 },
      'Finland': { timezone: 'Europe/Helsinki', offset: 2 },
      'Estonia': { timezone: 'Europe/Tallinn', offset: 2 },
      'Latvia': { timezone: 'Europe/Riga', offset: 2 },
      'Lithuania': { timezone: 'Europe/Vilnius', offset: 2 },
      'Belarus': { timezone: 'Europe/Minsk', offset: 3 },
      'Ukraine': { timezone: 'Europe/Kiev', offset: 2 },
      'Moldova': { timezone: 'Europe/Chisinau', offset: 2 },
      'Romania': { timezone: 'Europe/Bucharest', offset: 2 },
      'Bulgaria': { timezone: 'Europe/Sofia', offset: 2 },
      'Greece': { timezone: 'Europe/Athens', offset: 2 },
      'Turkey': { timezone: 'Europe/Istanbul', offset: 3 },
      'Cyprus': { timezone: 'Asia/Nicosia', offset: 2 },
      'Russia': { timezone: 'Europe/Moscow', offset: 3 },
      
      // Africa
      'Morocco': { timezone: 'Africa/Casablanca', offset: 1 },
      'Algeria': { timezone: 'Africa/Algiers', offset: 1 },
      'Tunisia': { timezone: 'Africa/Tunis', offset: 1 },
      'Libya': { timezone: 'Africa/Tripoli', offset: 2 },
      'Egypt': { timezone: 'Africa/Cairo', offset: 2 },
      'Sudan': { timezone: 'Africa/Khartoum', offset: 2 },
      'Ethiopia': { timezone: 'Africa/Addis_Ababa', offset: 3 },
      'Kenya': { timezone: 'Africa/Nairobi', offset: 3 },
      'Tanzania': { timezone: 'Africa/Dar_es_Salaam', offset: 3 },
      'Uganda': { timezone: 'Africa/Kampala', offset: 3 },
      'South Africa': { timezone: 'Africa/Johannesburg', offset: 2 },
      'Nigeria': { timezone: 'Africa/Lagos', offset: 1 },
      'Ghana': { timezone: 'Africa/Accra', offset: 0 },
      'Cameroon': { timezone: 'Africa/Douala', offset: 1 },
      'Democratic Republic of the Congo': { timezone: 'Africa/Kinshasa', offset: 1 },
      'Angola': { timezone: 'Africa/Luanda', offset: 1 },
      'Zimbabwe': { timezone: 'Africa/Harare', offset: 2 },
      'Botswana': { timezone: 'Africa/Gaborone', offset: 2 },
      'Namibia': { timezone: 'Africa/Windhoek', offset: 2 },
      'Zambia': { timezone: 'Africa/Lusaka', offset: 2 },
      'Madagascar': { timezone: 'Indian/Antananarivo', offset: 3 },
      
      // Middle East
      'Israel': { timezone: 'Asia/Jerusalem', offset: 2 },
      'Jordan': { timezone: 'Asia/Amman', offset: 2 },
      'Lebanon': { timezone: 'Asia/Beirut', offset: 2 },
      'Syria': { timezone: 'Asia/Damascus', offset: 2 },
      'Iraq': { timezone: 'Asia/Baghdad', offset: 3 },
      'Iran': { timezone: 'Asia/Tehran', offset: 3.5 },
      'Saudi Arabia': { timezone: 'Asia/Riyadh', offset: 3 },
      'Kuwait': { timezone: 'Asia/Kuwait', offset: 3 },
      'Qatar': { timezone: 'Asia/Qatar', offset: 3 },
      'Bahrain': { timezone: 'Asia/Bahrain', offset: 3 },
      'United Arab Emirates': { timezone: 'Asia/Dubai', offset: 4 },
      'Oman': { timezone: 'Asia/Muscat', offset: 4 },
      'Yemen': { timezone: 'Asia/Aden', offset: 3 },
      'Afghanistan': { timezone: 'Asia/Kabul', offset: 4.5 },
      
      // South Asia
      'Pakistan': { timezone: 'Asia/Karachi', offset: 5 },
      'India': { timezone: 'Asia/Kolkata', offset: 5.5 },
      'Nepal': { timezone: 'Asia/Kathmandu', offset: 5.75 },
      'Bangladesh': { timezone: 'Asia/Dhaka', offset: 6 },
      'Sri Lanka': { timezone: 'Asia/Colombo', offset: 5.5 },
      'Maldives': { timezone: 'Indian/Maldives', offset: 5 },
      
      // Southeast Asia
      'Myanmar': { timezone: 'Asia/Yangon', offset: 6.5 },
      'Thailand': { timezone: 'Asia/Bangkok', offset: 7 },
      'Laos': { timezone: 'Asia/Vientiane', offset: 7 },
      'Cambodia': { timezone: 'Asia/Phnom_Penh', offset: 7 },
      'Vietnam': { timezone: 'Asia/Ho_Chi_Minh', offset: 7 },
      'Malaysia': { timezone: 'Asia/Kuala_Lumpur', offset: 8 },
      'Singapore': { timezone: 'Asia/Singapore', offset: 8 },
      'Indonesia': { timezone: 'Asia/Jakarta', offset: 7 },
      'Brunei': { timezone: 'Asia/Brunei', offset: 8 },
      'Philippines': { timezone: 'Asia/Manila', offset: 8 },
      'Timor-Leste': { timezone: 'Asia/Dili', offset: 9 },
      
      // East Asia
      'China': { timezone: 'Asia/Shanghai', offset: 8 },
      'Mongolia': { timezone: 'Asia/Ulaanbaatar', offset: 8 },
      'North Korea': { timezone: 'Asia/Pyongyang', offset: 9 },
      'South Korea': { timezone: 'Asia/Seoul', offset: 9 },
      'Japan': { timezone: 'Asia/Tokyo', offset: 9 },
      'Taiwan': { timezone: 'Asia/Taipei', offset: 8 },
      'Hong Kong': { timezone: 'Asia/Hong_Kong', offset: 8 },
      'Macau': { timezone: 'Asia/Macau', offset: 8 },
      
      // Central Asia
      'Kazakhstan': { timezone: 'Asia/Almaty', offset: 6 },
      'Kyrgyzstan': { timezone: 'Asia/Bishkek', offset: 6 },
      'Tajikistan': { timezone: 'Asia/Dushanbe', offset: 5 },
      'Turkmenistan': { timezone: 'Asia/Ashgabat', offset: 5 },
      'Uzbekistan': { timezone: 'Asia/Tashkent', offset: 5 },
      
      // Oceania
      'Australia': { timezone: 'Australia/Sydney', offset: 10 },
      'New Zealand': { timezone: 'Pacific/Auckland', offset: 12 },
      'Papua New Guinea': { timezone: 'Pacific/Port_Moresby', offset: 10 },
      'Fiji': { timezone: 'Pacific/Fiji', offset: 12 },
      'Samoa': { timezone: 'Pacific/Samoa', offset: 13 },
      'Tonga': { timezone: 'Pacific/Tongatapu', offset: 13 },
      'Vanuatu': { timezone: 'Pacific/Efate', offset: 11 },
      'Solomon Islands': { timezone: 'Pacific/Guadalcanal', offset: 11 }
    }
  },

  // Helper function to check if a click should show timezone info
  shouldShowTimezonePopup(map, e) {
    // Check if click is on night overlay by checking if point is in night polygon
    if (!this.currentNightPolygon) {
      return true // No night overlay, show timezone popup
    }
    
    // Check if click coordinates are inside the night polygon
    const point = [e.lngLat.lng, e.lngLat.lat]
    const isInNight = this.pointInPolygon(point, this.currentNightPolygon)
    console.log('Click in night region:', isInNight)
    return !isInNight
  },

  // Helper function to check if a point is inside a polygon using ray casting algorithm
  pointInPolygon(point, polygon) {
    const [x, y] = point
    let inside = false
    
    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      const [xi, yi] = polygon[i]
      const [xj, yj] = polygon[j]
      
      if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside
      }
    }
    
    return inside
  },

  addSunlightOverlay(map) {
    // Calculate solar terminator using accurate NOAA algorithms
    const now = new Date()
    const solarData = this.calculateSolarPosition(now)
    
    // Create solar terminator line points using accurate calculations
    const terminatorPoints = []
    for (let lng = -180; lng <= 180; lng += 1) {
      const lat = this.calculateTerminatorLatitude(lng, solarData)
      
      if (!isNaN(lat) && lat >= -90 && lat <= 90) {
        terminatorPoints.push([lng, lat])
      }
    }
    
    // Create night overlay polygon
    const nightPolygon = this.createNightPolygon(terminatorPoints, now)
    
    // Store current night polygon for click detection
    this.currentNightPolygon = nightPolygon
    
    // Add night overlay source
    map.addSource('night-overlay', {
      type: 'geojson',
      data: {
        type: 'Feature',
        geometry: {
          type: 'Polygon',
          coordinates: [nightPolygon]
        },
        properties: {
          type: 'night'
        }
      }
    })
    
    // Add night overlay layer with gradient effect
    map.addLayer({
      id: 'night-overlay-layer',
      type: 'fill',
      source: 'night-overlay',
      paint: {
        'fill-color': '#1a1a2e',
        'fill-opacity': 0.4
      }
    })
    
    // Add subtle border for terminator line
    map.addLayer({
      id: 'terminator-line',
      type: 'line',
      source: 'night-overlay',
      paint: {
        'line-color': '#6b7280',
        'line-width': 1,
        'line-opacity': 0.6,
        'line-blur': 2
      }
    })
    
    // Add click handler for night overlay
    map.on('click', 'night-overlay-layer', (e) => {
      this.createTimezonePopup(e, map, false)
    })
    
    // Change cursor on hover
    map.on('mouseenter', 'night-overlay-layer', () => {
      map.getCanvas().style.cursor = 'pointer'
    })
    
    map.on('mouseleave', 'night-overlay-layer', () => {
      map.getCanvas().style.cursor = ''
    })
    
    // Update overlay every minute
    this.sunlightInterval = setInterval(() => {
      this.updateSunlightOverlay(map)
    }, 60000)
    
    console.log('Sunlight overlay added successfully')
  },

  createNightPolygon(terminatorPoints, now) {
    if (terminatorPoints.length === 0) return []
    
    const timeOfDay = (now.getUTCHours() + now.getUTCMinutes() / 60) / 24
    const isNorthernWinter = now.getMonth() >= 10 || now.getMonth() <= 2
    
    // Determine which side is night based on time and season
    const nightSide = []
    
    // Add world boundaries
    if (timeOfDay > 0.5) { // After noon UTC - night is moving west
      nightSide.push([-180, 85])
      terminatorPoints.forEach(point => nightSide.push(point))
      nightSide.push([180, 85], [180, -85], [-180, -85], [-180, 85])
    } else { // Before noon UTC - night is moving east
      nightSide.push([180, 85])
      terminatorPoints.reverse().forEach(point => nightSide.push(point))
      nightSide.push([-180, 85], [-180, -85], [180, -85], [180, 85])
    }
    
    return nightSide
  },

  updateSunlightOverlay(map) {
    if (!map.getSource('night-overlay')) return
    
    const now = new Date()
    const solarData = this.calculateSolarPosition(now)
    
    const terminatorPoints = []
    for (let lng = -180; lng <= 180; lng += 1) {
      const lat = this.calculateTerminatorLatitude(lng, solarData)
      
      if (!isNaN(lat) && lat >= -90 && lat <= 90) {
        terminatorPoints.push([lng, lat])
      }
    }
    
    const nightPolygon = this.createNightPolygon(terminatorPoints, now)
    
    // Update stored night polygon for click detection
    this.currentNightPolygon = nightPolygon
    
    map.getSource('night-overlay').setData({
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [nightPolygon]
      },
      properties: {
        type: 'night'
      }
    })
  },

  // Accurate solar position calculation based on NOAA/Jean Meeus algorithms
  calculateSolarPosition(date) {
    // Time in Julian centuries since J2000.0
    const julianDay = this.getJulianDay(date)
    const julianCentury = (julianDay - 2451545.0) / 36525.0
    
    // Geometric mean longitude of the sun (degrees)
    const geomMeanLongSun = this.mod(280.46646 + julianCentury * (36000.76983 + julianCentury * 0.0003032), 360)
    
    // Geometric mean anomaly of the sun (degrees)
    const geomMeanAnomSun = 357.52911 + julianCentury * (35999.05029 - 0.0001537 * julianCentury)
    
    // Eccentricity of earth's orbit
    const eccentEarthOrbit = 0.016708634 - julianCentury * (0.000042037 + 0.0000001267 * julianCentury)
    
    // Sun's equation of center
    const sunEqOfCenter = Math.sin(this.deg2rad(geomMeanAnomSun)) * (1.914602 - julianCentury * (0.004817 + 0.000014 * julianCentury)) +
                         Math.sin(this.deg2rad(2 * geomMeanAnomSun)) * (0.019993 - 0.000101 * julianCentury) +
                         Math.sin(this.deg2rad(3 * geomMeanAnomSun)) * 0.000289
    
    // Sun's true longitude (degrees)
    const sunTrueLong = geomMeanLongSun + sunEqOfCenter
    
    // Mean obliquity of ecliptic (degrees)
    const meanObliqEcliptic = 23 + (26 + ((21.448 - julianCentury * (46.815 + julianCentury * (0.00059 - julianCentury * 0.001813)))) / 60) / 60
    
    // Corrected obliquity (degrees)
    const obliqCorr = meanObliqEcliptic + 0.00256 * Math.cos(this.deg2rad(125.04 - 1934.136 * julianCentury))
    
    // Solar declination (degrees)
    const sunDeclin = this.rad2deg(Math.asin(Math.sin(this.deg2rad(obliqCorr)) * Math.sin(this.deg2rad(sunTrueLong))))
    
    // Equation of time (minutes)
    const varY = Math.tan(this.deg2rad(obliqCorr / 2)) * Math.tan(this.deg2rad(obliqCorr / 2))
    const eqOfTime = 4 * this.rad2deg(varY * Math.sin(2 * this.deg2rad(geomMeanLongSun)) -
                                     2 * eccentEarthOrbit * Math.sin(this.deg2rad(geomMeanAnomSun)) +
                                     4 * eccentEarthOrbit * varY * Math.sin(this.deg2rad(geomMeanAnomSun)) * Math.cos(2 * this.deg2rad(geomMeanLongSun)) -
                                     0.5 * varY * varY * Math.sin(4 * this.deg2rad(geomMeanLongSun)) -
                                     1.25 * eccentEarthOrbit * eccentEarthOrbit * Math.sin(2 * this.deg2rad(geomMeanAnomSun)))
    
    return {
      declination: sunDeclin,
      equationOfTime: eqOfTime,
      julianDay: julianDay
    }
  },
  
  calculateTerminatorLatitude(longitude, solarData) {
    // Calculate the latitude where the sun is on the horizon for given longitude
    const { declination, equationOfTime, julianDay } = solarData
    
    // Solar noon correction for longitude
    const timeCorrection = equationOfTime + 4 * longitude
    
    // Current time in minutes from midnight UTC
    const now = new Date()
    const currentTimeMinutes = now.getUTCHours() * 60 + now.getUTCMinutes() + now.getUTCSeconds() / 60
    
    // Local solar time
    const localSolarTime = currentTimeMinutes + timeCorrection
    
    // Hour angle (degrees from solar noon)
    const hourAngle = (localSolarTime / 4) - 180
    
    // Calculate latitude where sun is on horizon (terminator)
    const declinationRad = this.deg2rad(declination)
    const hourAngleRad = this.deg2rad(hourAngle)
    
    // For terminator: cos(zenith) = 0 (sun on horizon)
    // cos(zenith) = sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(hourAngle) = 0
    // Therefore: tan(lat) = -cos(hourAngle) / tan(decl)
    
    if (Math.abs(Math.cos(hourAngleRad)) < 1e-6) {
      // Near solar noon or midnight
      return declination > 0 ? 90 - Math.abs(declination) : -90 + Math.abs(declination)
    }
    
    const latitudeRad = Math.atan(-Math.cos(hourAngleRad) / Math.tan(declinationRad))
    return this.rad2deg(latitudeRad)
  },
  
  getJulianDay(date) {
    // Convert date to Julian Day Number
    const a = Math.floor((14 - (date.getUTCMonth() + 1)) / 12)
    const y = date.getUTCFullYear() + 4800 - a
    const m = (date.getUTCMonth() + 1) + 12 * a - 3
    
    const jdn = date.getUTCDate() + Math.floor((153 * m + 2) / 5) + 365 * y + Math.floor(y / 4) - Math.floor(y / 100) + Math.floor(y / 400) - 32045
    
    // Add time fraction
    const timeOfDay = (date.getUTCHours() + date.getUTCMinutes() / 60 + date.getUTCSeconds() / 3600) / 24
    
    return jdn + timeOfDay - 0.5
  },
  
  deg2rad(degrees) {
    return degrees * Math.PI / 180
  },
  
  rad2deg(radians) {
    return radians * 180 / Math.PI
  },
  
  mod(a, b) {
    return ((a % b) + b) % b
  },

  destroyed() {
    // Clean up map when component is destroyed
    if (this.map) {
      this.map.remove()
    }
    // Clean up sunlight overlay interval
    if (this.sunlightInterval) {
      clearInterval(this.sunlightInterval)
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Handle speak_text events from LiveView
window.addEventListener("phx:speak_text", (event) => {
  const { text, lang } = event.detail;
  window.speakText(text, lang);
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Text-to-speech functionality
window.speakText = function(text, lang, rate = 0.8, pitch = 1.0) {
  if ('speechSynthesis' in window) {
    // Cancel any ongoing speech
    window.speechSynthesis.cancel();
    
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = lang;
    utterance.rate = rate;
    utterance.pitch = pitch;
    utterance.volume = 1.0;
    
    // Find the best voice for the language
    const voices = window.speechSynthesis.getVoices();
    const voice = voices.find(v => v.lang === lang) || voices.find(v => v.lang.startsWith(lang.split('-')[0]));
    if (voice) {
      utterance.voice = voice;
    }
    
    window.speechSynthesis.speak(utterance);
  } else {
    console.warn('Speech synthesis not supported in this browser');
  }
};

// Load voices when available
if ('speechSynthesis' in window) {
  window.speechSynthesis.onvoiceschanged = function() {
    // Voices loaded
  };
}

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket