# SayMyName — Design System & UI Guidelines

## Overview
SayMyName is a name pronunciation web app with an iOS companion. Users create a name card with their name in multiple languages/scripts, share it with others, and organize names into lists for daily practice. The app also features public stats for exploring trending names across languages.

---

## 🎯 Design Principles

1. **The core action is playing a name. It must be 1 tap from launch.**
2. My Card is setup-once. It does not deserve a primary tab.
3. Share is an action, not a destination.
4. Map/Directory/Work Hours/Holidays belong to the old Zonely app — removed from SayMyName.

---

## 📱 Navigation: 3 Tabs

```
┌────────────────────────────────────────────────┐
│                                                │
│              (page content)                    │
│                                                │
├────────────┬───────────────┬───────────────────┤
│  📋 Lists  │  🔍 Explore   │      👤 Me        │
│  (home)    │               │                   │
└────────────┴───────────────┴───────────────────┘
```

| Tab | What | Frequency |
|-----|------|-----------|
| **📋 Lists** (home) | Active list with playable names. List switcher in header. | **Daily** |
| **🔍 Explore** | Trending names, popular languages, countries. Fun stats. | Occasional |
| **👤 Me** | My Card, About, Privacy, Feedback, cross-promo | Rare |

- **Mobile**: Bottom tab bar (standard iOS pattern)
- **Desktop**: Top navigation bar (same 3 items)

### URL Structure

```
/                     → Lists (home) — shows most recent list
/lists/:id            → Specific list detail
/explore              → Public stats, trending
/me                   → Profile: My Card, About, etc.
/me/card              → My Card edit view (legacy: /my-name-card still works)
/card/:token          → Import card (inbound share, transient)
/list/:token          → Import list (inbound share, transient)
```

---

## 📄 Page Designs

### Lists — HOME (`/`)

The app opens here. Active list with names immediately playable.

**Core action: 1 tap.** Open app → ▶ on any name.

- **List switcher** in header (tap list name ▾ to switch)
- **Each name row**: ▶ plays default language; tap row expands language variants
- **Share button** at bottom of list
- **New user**: Onboarding welcome → "Set Up My Name Card" primary CTA
- **Returning user with lists**: Most recently accessed list, names visible

### Explore (`/explore`)

Fun, public-facing stats. Everything here is playable and shareable to social.

- Hero stat: total pronunciations + languages
- Trending names with ▶ play buttons
- Names around the world (country flags + counts)
- Popular languages (horizontal bars)
- Each section has 📤 share-to-social button (generates branded image card)

### Me (`/me`)

Profile hub: My Card preview + app meta + social/cross-promo.

- **My Name Card**: Preview with Edit + Share buttons (or empty state CTA)
- **App section**: How It Works, Privacy, Send Feedback
- **Spread the Word**: Get iOS App (web) / Use on Web (iOS) / Share SayMyName

---

## 🔗 Social & Cross-Promotion

| Location | What's shared | Generated image? |
|----------|--------------|-----------------|
| My Card → Share | Personal name card link + visual | ✅ Visual card with name in all languages |
| List → Share this list | List link | ❌ Just a link |
| Explore → 📤 on section | Stat highlight | ✅ Visual card with trending/stats |
| Me → Share SayMyName | App promo | ✅ Feature-highlight card |

### Cross-promotion
- **Web → iOS**: Smart App Banner on all pages, "Get the App" in Me tab
- **iOS → Web**: Share actions generate web URLs, "Use on the Web" in Me tab
- Social card format: 1200×628px, dark bg, bold native-script typography

---

## 🔄 User Flows

### Flow A: New User (Cold Start)
```
Open app → Home (onboarding) → "Set Up My Name Card" → Edit card → Save → Me tab → Share
```

### Flow B: Receiving a Name Card
```
Tap shared link → Card preview → Play ▶ → "Add to list" → Pick/create list → Import → Home
```

### Flow C: Daily Use (MOST FREQUENT)
```
Open app → Home = active list → ▶ (1 tap total)
```

### Flow D: Switch Teams
```
Home → tap list name ▾ → List switcher → tap new list → Home shows that list
```

### Flow E: Archive Old List
```
Home → ▾ → list switcher → swipe/long-press → Archive → Collapsed section
```

### Landing Logic

| User state | Home shows | Why |
|------------|-----------|-----|
| Brand new | Onboarding welcome | Guide to setup |
| Has card, no lists | Welcome + "Share your card to start building lists" | Bridge to core loop |
| Has 1+ lists | Most recently accessed list | **1 tap to play** |
| Deep link | Import flow → then redirect to Home | Seamless |

---

## ♿ Accessibility

- Bottom tabs: `role="tablist"` with `role="tab"` and `aria-selected`
- All tabs show icon + text label (never icon-only)
- Play buttons: `aria-label="Play pronunciation of [name] in [language]"`
- List switcher dropdown: `aria-haspopup="listbox"`, `aria-expanded`
- Share modals: focus trap, close on Escape, `aria-modal="true"`
- All interactive elements: visible focus ring (min 2px, 3:1 contrast against adjacent)
- All text: min 4.5:1 contrast ratio
- Tap targets: min 44×44px (iOS HIG) / 48×48dp (Material)
- Spacing: 8px grid throughout

---

## 🎨 Visual Design

### Spacing
- 8px grid: all spacing is multiples of 8px (8, 16, 24, 32, 40, 48)
- `p-2` = 8px, `p-4` = 16px, `p-6` = 24px, `p-8` = 32px

### Typography
- **Page titles**: text-2xl (24px) font-bold, gray-900
- **Section headers**: text-lg (18px) font-semibold, gray-900
- **Body**: text-sm (14px), gray-600
- **Names in lists**: text-base (16px) font-medium, gray-900

### Colors
- **Primary action**: blue-600 (hover: blue-700, focus ring: blue-500)
- **Play button**: emerald-600 (hover: emerald-700)
- **Share action**: green-600
- **Destructive**: red-600
- **Backgrounds**: white (cards), gray-50 (page bg), gray-100 (subtle sections)
- **Active tab**: blue-600 text + indicator
- **Inactive tab**: gray-500 text

---

## 📝 Implementation Status

### ✅ Completed
- [x] Name card create/edit/share
- [x] Collections/lists CRUD
- [x] Import name card via share link
- [x] Analytics dashboard (admin)
- [x] Multi-source pronunciation (Forvo → NameShouts → AWS Polly)

### 🔄 In Progress
- [ ] 3-tab navigation (Lists, Explore, Me)
- [ ] Lists as home page with 1-tap-to-play
- [ ] Explore page (public stats)
- [ ] Me page (My Card + About + cross-promo)
- [ ] Remove old Zonely routes (Map, Directory, Work Hours, Holidays)

### 📋 Planned
- [ ] Social share card image generation
- [ ] Smart App Banner for iOS cross-promo
- [ ] List switcher dropdown in header
- [ ] Archive/unarchive lists
- [ ] Onboarding flow for new users

---

*Last updated: 2026-02-21*
*Version: 2.0*