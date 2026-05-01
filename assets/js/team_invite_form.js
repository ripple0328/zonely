function formatMinutes(minutes) {
  const value = Number.parseInt(minutes, 10)

  if (!Number.isFinite(value)) {
    return ""
  }

  const hours = String(Math.floor(value / 60)).padStart(2, "0")
  const mins = String(value % 60).padStart(2, "0")

  return `${hours}:${mins}`
}

export function setupTeamInviteForm() {
  setupProgressiveComboboxes()
  setupWorkWindowRanges()
}

function setupProgressiveComboboxes() {
  const comboboxes = document.querySelectorAll("[data-progressive-combobox]")

  comboboxes.forEach((combobox) => {
    const input = combobox.querySelector("[data-combobox-input]")
    const valueInput = combobox.querySelector("[data-combobox-value]")
    const list = combobox.querySelector("[data-combobox-list]")
    const options = Array.from(combobox.querySelectorAll("[data-combobox-option]"))

    if (!input || !list || options.length === 0) {
      return
    }

    let activeIndex = -1
    let visibleOptions = []

    const normalize = (value) => {
      return value
        .trim()
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
    }

    const tokenize = (value) => normalize(value).split(/[^a-z0-9]+/).filter(Boolean)

    const optionMatches = (option, terms) => {
      const tokens = tokenize(option.dataset.search || option.dataset.label || option.textContent || "")

      return terms.every((term) => tokens.some((token) => token.startsWith(term)))
    }

    const syncValue = () => {
      if (!valueInput) {
        return
      }

      const query = normalize(input.value)
      const exact = options.find((option) => {
        return normalize(option.dataset.label || "") === query || normalize(option.dataset.value || "") === query
      })

      valueInput.value = exact ? exact.dataset.value : input.value.trim()
    }

    const setActiveOption = (index) => {
      visibleOptions.forEach((option) => {
        option.classList.remove("is-active")
        option.setAttribute("aria-selected", "false")
      })

      activeIndex = index
      const option = visibleOptions[activeIndex]

      if (option) {
        option.classList.add("is-active")
        option.setAttribute("aria-selected", "true")
        input.setAttribute("aria-activedescendant", option.id)
        option.scrollIntoView({block: "nearest"})
      } else {
        input.removeAttribute("aria-activedescendant")
      }
    }

    const closeList = () => {
      list.hidden = true
      input.setAttribute("aria-expanded", "false")
      setActiveOption(-1)
    }

    const updateOptions = ({open = false} = {}) => {
      const terms = tokenize(input.value)

      visibleOptions = options.filter((option) => {
        const matches = optionMatches(option, terms)
        option.hidden = !matches
        return matches
      })

      if (open && visibleOptions.length > 0) {
        list.hidden = false
        input.setAttribute("aria-expanded", "true")
        setActiveOption(Math.min(Math.max(activeIndex, -1), visibleOptions.length - 1))
      } else {
        closeList()
      }
    }

    const selectOption = (option) => {
      input.value = option.dataset.label || option.dataset.value || ""

      if (valueInput) {
        valueInput.value = option.dataset.value || input.value
      }

      closeList()
    }

    input.addEventListener("focus", () => updateOptions({open: true}))

    input.addEventListener("input", () => {
      syncValue()
      activeIndex = -1
      updateOptions({open: true})
    })

    input.addEventListener("keydown", (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault()
        updateOptions({open: true})

        if (visibleOptions.length > 0) {
          setActiveOption((activeIndex + 1) % visibleOptions.length)
        }
      }

      if (event.key === "ArrowUp") {
        event.preventDefault()
        updateOptions({open: true})

        if (visibleOptions.length > 0) {
          setActiveOption((activeIndex - 1 + visibleOptions.length) % visibleOptions.length)
        }
      }

      if (event.key === "Enter" && !list.hidden && visibleOptions[activeIndex]) {
        event.preventDefault()
        selectOption(visibleOptions[activeIndex])
      }

      if (event.key === "Escape") {
        closeList()
      }
    })

    input.addEventListener("blur", () => {
      syncValue()
      window.setTimeout(closeList, 120)
    })

    options.forEach((option) => {
      option.addEventListener("mousedown", (event) => {
        event.preventDefault()
        selectOption(option)
      })
    })

    syncValue()
    updateOptions()
  })
}

function setupWorkWindowRanges() {
  const ranges = document.querySelectorAll("[data-work-window-range]")

  ranges.forEach((range) => {
    const startInput = range.querySelector('[data-work-window-handle="start"]')
    const endInput = range.querySelector('[data-work-window-handle="end"]')
    const fill = range.querySelector("[data-work-window-fill]")
    const output = range.querySelector("[data-work-window-output]")

    if (!startInput || !endInput || !fill || !output) {
      return
    }

    const minGap = Number.parseInt(range.dataset.minGap || "30", 10)
    const min = Number.parseInt(startInput.min || "0", 10)
    const max = Number.parseInt(startInput.max || "1410", 10)
    const span = max - min

    const clamp = (value) => Math.min(max, Math.max(min, value))

    const setActiveHandle = (handle) => {
      startInput.dataset.activeHandle = handle === "start" ? "true" : "false"
      endInput.dataset.activeHandle = handle === "end" ? "true" : "false"
    }

    const update = (changedHandle) => {
      let start = clamp(Number.parseInt(startInput.value, 10))
      let end = clamp(Number.parseInt(endInput.value, 10))

      if (changedHandle === "start" && start > end - minGap) {
        start = Math.max(min, end - minGap)
        startInput.value = String(start)
      }

      if (changedHandle === "end" && end < start + minGap) {
        end = Math.min(max, start + minGap)
        endInput.value = String(end)
      }

      if (changedHandle === undefined && start > end - minGap) {
        end = Math.min(max, start + minGap)
        endInput.value = String(end)
      }

      const left = ((start - min) / span) * 100
      const right = 100 - ((end - min) / span) * 100

      fill.style.left = `${left}%`
      fill.style.right = `${right}%`
      output.textContent = `${formatMinutes(start)}–${formatMinutes(end)}`
      startInput.setAttribute("aria-valuetext", formatMinutes(start))
      endInput.setAttribute("aria-valuetext", formatMinutes(end))
    }

    startInput.addEventListener("pointerdown", () => setActiveHandle("start"))
    endInput.addEventListener("pointerdown", () => setActiveHandle("end"))
    startInput.addEventListener("focus", () => setActiveHandle("start"))
    endInput.addEventListener("focus", () => setActiveHandle("end"))
    startInput.addEventListener("input", () => update("start"))
    endInput.addEventListener("input", () => update("end"))
    update()
  })
}
