# Say My Name - iOS

**The ultimate pronunciation learning app for multilingual names**

Say My Name is a beautiful, native iOS app that helps you learn and share the correct pronunciation of names in any language. Whether you're meeting international colleagues, learning family names, or simply want to pronounce someone's name correctly, this app has you covered.

## ✨ Key Features

### 🎯 **Smart Name Management**
- Add names in multiple languages with accurate pronunciation
- Intelligent language detection with mismatch warnings
- Beautiful, intuitive SwiftUI interface with glass morphism design
- Support for 10+ languages including English, Chinese, Spanish, French, German, and more

### 🔊 **High-Quality Audio**
- Human-recorded pronunciations when available
- Automatic fallback to high-quality text-to-speech
- Instant audio playback with visual feedback
- Smart caching system for offline access

### 🌍 **Multilingual Support**
- Fully localized in 10 languages
- Automatic language detection for text input
- Support for complex multilingual names
- BCP-47 compliant language codes

### 📱 **Native iOS Experience**
- Built with SwiftUI for iOS 16+
- Smooth animations and haptic feedback
- Optimized for both iPhone and iPad
- Follows Apple's Human Interface Guidelines

### 🔗 **Seamless Sharing**
- Share name lists via deep links
- Works with both custom URL schemes and HTTPS links
- Secure Base64 encoding for data transmission
- Cross-platform compatibility

### 💾 **Smart Caching**
- Automatic audio caching for instant replay
- Intelligent cache management with size limits
- Optional cache clearing for storage management
- Persistent storage across app sessions

## 🎨 Design Highlights

- **Glass Morphism UI** - Modern, translucent interface elements
- **Avatar Generation** - Unique visual identifiers for each name
- **Adaptive Layout** - Optimized for different screen sizes
- **Accessibility** - Full VoiceOver and accessibility support
- **Dark Mode Ready** - Seamless integration with system preferences

## 🚀 Getting Started

### Requirements
- iOS 16.0 or later
- Xcode 15+ (for development)
- Internet connection for pronunciation services

### Installation
1. Clone the repository
2. Open `say my name.xcodeproj` in Xcode
3. Build and run on your device or simulator

### Usage
1. **Add Names**: Enter a name in English and/or native script
2. **Select Languages**: Choose appropriate language variants
3. **Play Audio**: Tap language pills to hear pronunciations
4. **Share Lists**: Use the share button to send name collections
5. **Manage Cache**: Clear cached audio when needed

## 🔧 Technical Features

### Architecture
- **MVVM Pattern** with SwiftUI and Combine
- **Protocol-Oriented** networking and audio layers
- **Dependency Injection** for testing and modularity
- **Clean Separation** between UI, business logic, and data layers

### Audio System
- **AVFoundation** integration for high-quality playback
- **Background Audio** support with proper session management
- **Sequential Playback** for multiple pronunciations
- **Error Handling** with automatic TTS fallback

### Data Management
- **Core Data** alternative with simple JSON persistence
- **Deep Link** support with secure data encoding
- **State Restoration** across app launches
- **Memory Efficient** caching with LRU eviction

## 🧪 Testing

The app includes comprehensive test coverage:
- **Unit Tests** for core business logic
- **Integration Tests** for networking and audio
- **UI Tests** for critical user flows
- **Performance Tests** for caching and data operations

## 📄 License

This project is available under the MIT License. See LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests, report bugs, or suggest new features.

---

*Say My Name - Because every name deserves to be pronounced correctly.* 🗣️

