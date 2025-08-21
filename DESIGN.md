# Zonely - Design System & UI Guidelines

## Overview
Zonely is a timezone-aware collaboration tool that helps teams understand "where" and "when" their colleagues are. The interface uses two distinct popup types to provide contextual information efficiently.

---

## 🎯 Design Philosophy

### Rule of Thumb
- **Timezone Popup** = "Where + When" (Place-centric)
- **Profile Popup** = "Who + How" (Person-centric)

### Interaction Model
- **Map Click** → Quick time awareness (fast)
- **Avatar Click** → Human details & contact info (deep)

---

## 📍 Timezone Click Popup (Place-centric)

### Purpose
Quick time awareness for collaboration. Keep it lightweight and glanceable.

### Content Structure
```
📍 🇺🇸 Los Angeles
🕒 2025/08/21-15:34
⏳ +3 hours ahead of you
🟢 Working hours
```

### Information Hierarchy
1. **Location** (Primary): City name with flag for geographic context
2. **Time & Date** (Essential): Current local time in compact format
3. **Relative Time** (Contextual): Difference from user's timezone
4. **Working Status** (Visual): Color-coded dot + status text

### Visual Design
- **Day regions**: Light theme with sun icon (☀️)
- **Night regions**: Dark theme with moon icon (🌙)
- **Compact layout**: Minimal padding, efficient use of space
- **Smooth animations**: Fade-in with subtle slide effect

### Working Hours Indicators
- 🟢 **Green**: Working hours (9 AM - 5 PM)
- 🟠 **Orange**: Evening hours (5 PM - 10 PM)
- 🟣 **Purple**: Night hours (10 PM - 6 AM)
- 🟡 **Yellow**: Morning hours (6 AM - 9 AM)
- 🔵 **Blue**: Weekend

---

## 👤 Profile Popup (Person-centric)

### Purpose
Who they are + how to reach them. Richer content for human connection.

### Content Structure *(Future Implementation)*
```
👤 Sarah Chen (she/her)
🏢 Design Team • Senior Designer
📍 🇺🇸 Los Angeles
🕒 2025/08/21-15:34 (Working hours)
⏳ Available until 5pm
💬 [Chat] [Email] [Calendar]
🟢 Available
```

### Information Hierarchy
1. **Identity**: Name, pronouns, role, team
2. **Location**: City with flag (pulled from timezone data)
3. **Time Context**: Current local time + availability
4. **Contact Methods**: Quick action buttons
5. **Status**: Current availability/presence

### Interaction Patterns
- **Primary**: Click avatar to open
- **Secondary**: Hover for quick status preview
- **Actions**: Direct communication shortcuts

---

## 🎨 Visual Design System

### Color Palette
- **Day theme**: Light grays, white background
- **Night theme**: Dark blues/purples with golden accents
- **Status colors**: Semantic green/orange/purple/yellow/blue
- **Flags**: Unicode country flags for instant recognition

### Typography
- **Headers**: Font weight 700, larger size for hierarchy
- **Body**: 0.75rem with proper line-height for readability
- **Compact dates**: YYYY/MM/DD-HH:MM format for efficiency

### Animation Principles
- **Duration**: 0.25s for snappy, responsive feel
- **Easing**: ease-out for natural motion
- **Effects**: Fade-in + subtle scale/slide
- **Performance**: CSS transforms for smooth rendering

### Spacing System
- **Tight**: 0.25rem gaps for related elements
- **Normal**: 0.5rem between sections
- **Relaxed**: 0.75rem for visual separation

---

## 🔧 Technical Implementation

### Component Architecture
```javascript
// Single template function with theme variants
createTimezonePopup(e, map, isDayTime)
// Future: createProfilePopup(user, isDayTime)
```

### Data Processing
- **Timezone conversion**: Handles DST automatically
- **Location mapping**: Technical names → Human-readable cities
- **Status calculation**: Real-time working hours detection
- **Relative time**: Dynamic calculation from user's timezone

### Responsive Behavior
- **Popup positioning**: Smart placement to avoid screen edges
- **Content adaptation**: Graceful handling of unknown timezones
- **Performance**: Efficient re-rendering with cached calculations

---

## 📊 Accessibility Guidelines

### Visual Accessibility
- **Color contrast**: High contrast ratios for readability
- **Icon redundancy**: Text labels accompany all color indicators
- **Font sizing**: Readable at standard zoom levels

### Interaction Accessibility
- **Keyboard navigation**: All popups accessible via keyboard
- **Screen readers**: Semantic HTML with proper ARIA labels
- **Focus management**: Clear focus indicators and logical tab order

---

## 🚀 Future Enhancements

### Timezone Popup Evolution
- **Clock arc visualization**: Circular progress for day/night cycle
- **Weather integration**: Basic weather icons for context
- **Holiday awareness**: Special indicators for local holidays

### Profile Popup Features
- **Calendar integration**: Show next available meeting slot
- **Presence sync**: Real-time status from communication tools
- **Time preferences**: Personal working hour overrides
- **Contact preferences**: Preferred communication methods

### System Improvements
- **Multi-timezone comparison**: Side-by-side time views
- **Meeting scheduler**: Find optimal meeting times
- **Notification system**: Smart alerts for timezone changes
- **Personalization**: Star/pin frequent collaborators

---

## 📝 Implementation Status

### ✅ Completed
- [x] Timezone popup redesign (place-centric)
- [x] Location mapping (cities vs technical names)
- [x] Working hours visualization
- [x] Day/night theme variants
- [x] Smooth animations
- [x] Compact date/time format
- [x] Relative time calculation

### 🔄 In Progress
- [ ] Profile popup design
- [ ] Clock arc visualization
- [ ] Enhanced accessibility features

### 📋 Planned
- [ ] Calendar integration
- [ ] Multi-timezone comparison
- [ ] Meeting scheduler
- [ ] Personalization features

---

*Last updated: 2025-08-21*
*Version: 1.0*