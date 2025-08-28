# App Store Screenshots Guide

## Required Screenshot Sizes

You must provide:
- EITHER a large iPhone size: 6.7" (preferred) OR 6.5"
- 5.5" iPhone
- 12.9" iPad Pro if your app supports iPad

### iPhone (6.7" Display) - **Required (one of 6.7" or 6.5")**
- **Dimensions**: 1290 × 2796 pixels
- **Device**: iPhone 15 Pro Max, iPhone 14 Pro Max, iPhone 13 Pro Max, iPhone 12 Pro Max
- **Orientation**: Portrait
- **Count**: 1-10 screenshots

### iPhone (6.5" Display) - **Required (one of 6.7" or 6.5")**  
- **Dimensions**: 1242 × 2688 pixels
- **Device**: iPhone 11 Pro Max, iPhone XS Max
- **Orientation**: Portrait
- **Count**: 1-10 screenshots

### iPhone (5.5" Display) - **REQUIRED**
- **Dimensions**: 1242 × 2208 pixels  
- **Device**: iPhone 8 Plus, iPhone 7 Plus, iPhone 6s Plus
- **Orientation**: Portrait
 - **Count**: 1-10 screenshots

### iPad Pro (12.9" 3rd Gen) - **REQUIRED if iPad supported**
- **Dimensions**: 2048 × 2732 pixels
- **Device**: iPad Pro 12.9" (3rd gen and later)
- **Orientation**: Portrait
- **Count**: 1-10 screenshots

## Screenshot Content Plan

### Screenshot 1: Main screen with entries and playback
**Title**: "Hear authentic pronunciations"
**Content**:
- Show the main interface with 3–4 sample names
- Display avatars, name headings, and per-language pills
- One pill in the "playing" state; show human vs TTS indicator
- Showcase the glass-morphism cards and overall polish

### Screenshot 2: Add names in multiple languages (validation)
**Title**: "Smart language validation"
**Content**:
- Show both text fields filled (e.g., English + Native)
- Open at least one language picker menu
- Show mismatch warning state (orange badge + helper text)
- Highlight the Add button (enabled when valid)

### Screenshot 3: Human vs TTS and multiple languages
**Title**: "Real voices with smart fallbacks"
**Content**:
- Show pills for at least two languages
- Indicate one as human, another as TTS
- Display the playing state on one pill
- Keep layout with two equal-width pills when applicable

### Screenshot 4: Share and deep links
**Title**: "Share pronunciation lists"
**Content**:
- Show the Share button and iOS share sheet
- Mention deep links open the app and load shared names
- Show multiple name entries ready to be shared

### Screenshot 5: Cache management
**Title**: "Manage cached pronunciations"
**Content**:
- Show cache count and size summary
- Show the Clear button and confirmation alert
- Keep consistent glass card styling

## How to Capture Screenshots

### Using Xcode Simulator
1. **Open Xcode** → **Open Developer Tool** → **Simulator**
2. **Choose Device**: iPhone 15 Pro Max (6.7") OR iPhone 11 Pro Max (6.5")
3. **Set Language**: Device → Language & Region → English
4. **Launch your app** from simulator
5. **Capture**: Device → Screenshot (⌘+S)
6. **Repeat** for iPhone 8 Plus (5.5") and iPad Pro 12.9" (if supported)

### Using Real Device (Alternative)
1. **Connect iPhone/iPad** to Mac
2. **Open Xcode** → **Window** → **Devices and Simulators**
3. **Select your device** → **Take Screenshot**
4. **Save** to desired location

### Screenshot Tips
- **Use sample data** that looks realistic and diverse
- **Show the app in its best state** - no empty screens
- **Include diverse names** from different cultures
- **Ensure text is readable** at thumbnail size
- **Use consistent lighting** and background
- **Avoid showing personal information**

## Sample Data for Screenshots

```
Names to include in screenshots:
1. "Zhang Wei" (张伟) - Chinese
2. "María Rodríguez" (María Rodríguez) - Spanish  
3. "Hiroshi Tanaka" (田中浩) - Japanese
4. "Priya Sharma" (प्रिया शर्मा) - Hindi
5. "Ahmed Hassan" (أحمد حسن) - Arabic
6. "Sophie Dubois" - French
7. "Klaus Müller" - German
8. "Amina Youssef" (أمينة يوسف) - Arabic (alt)
```

## Post-Processing (Optional)

### Tools
- **Preview** (Mac built-in) - Basic editing
- **Figma** (Free) - Add text overlays and annotations
- **Canva** (Free tier) - Add marketing text and backgrounds

### Enhancements
- Add subtle drop shadows
- Include descriptive text overlays
- Ensure screenshots look professional
- Maintain consistent visual style across all screenshots
- Consider adding device frames for marketing appeal

## Submission Format
- **File format**: PNG or JPEG
- **Color space**: RGB
- **File size**: Up to 10 MB per screenshot
- **Upload**: Directly in App Store Connect under "App Store Screenshots"

## Testing Checklist
- [ ] Screenshots match required dimensions exactly
- [ ] All text is legible and professional
- [ ] App appears functional and polished
- [ ] No placeholder or debug content visible
- [ ] Diverse, inclusive content shown
- [ ] Screenshots tell a clear story about app functionality
- [ ] Visual consistency across all screenshots
- [ ] Screenshots work well as thumbnails

## Alternative: App Preview Video
Consider creating a 15-30 second video showing:
1. Opening the app
2. Adding a name
3. Playing pronunciation
4. Showing the language variety

Video specs:
- **Resolution**: 1920×1080 or device-specific
- **Duration**: 15-30 seconds  
- **Format**: .mov, .mp4, .m4v
- **File size**: Maximum 500MB