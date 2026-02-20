# Deep Link Setup Guide

## Overview
Deep linking allows users to share pronunciation lists via URLs that can open directly in the Say My Name app or prompt users to install the app if they don't have it.

## URL Scheme
- **Custom Scheme**: `saymyname://`
- **HTTPS Domain**: `https://saymyname.qingbo.us`
- **Parameter**: `?s=BASE64_ENCODED_DATA`

## Example URLs
```
Custom scheme: saymyname://?s=W3sibmFtZSI6IueOi-aYjiIsImVudHJpZXMiOlt7ImxhbmciOiJlbi1VUyIsInRleHQiOiJNaW5nIFdhbmcifV19XQ

HTTPS fallback: https://saymyname.qingbo.us/?s=W3sibmFtZSI6IueOi-aYjiIsImVudHJpZXMiOlt7ImxhbmciOiJlbi1VUyIsInRleHQiOiJNaW5nIFdhbmcifV19XQ
```

## iOS App Configuration

### 1. URL Scheme Registration
Added to `project.pbxproj`:
```
INFOPLIST_KEY_CFBundleURLTypes = (
    {
        CFBundleURLName = "us.qingbo.saymyname";
        CFBundleURLSchemes = (
            "saymyname"
        );
    }
);
```

### 2. Deep Link Handling
In `say_my_nameApp.swift`:
```swift
.onOpenURL { url in
    viewModel.loadFromDeepLink(url: url)
}
```

### 3. URL Parsing Logic
In `AppViewModel.swift` - `loadFromDeepLink()` method handles:
- Custom scheme URLs (`saymyname://`)
- HTTPS URLs (`https://saymyname.qingbo.us`)
- Base64 URL-safe decoding
- JSON parsing and data validation
- Loading shared names into the app

## Web Integration

### 1. Smart App Banner
Add to website's `<head>`:
```html
<meta name="apple-itunes-app" content="app-id=YOUR_APP_ID, app-argument=https://saymyname.qingbo.us/">
```

### 2. App Store ID
Replace `YOUR_APP_ID` with actual App Store ID after app approval:
- In `AppConfig.swift`
- In `WEB_SMART_APP_BANNER.html`
- In website meta tags

### 3. Fallback Behavior
The web page (`WEB_SMART_APP_BANNER.html`) provides:
- Smart App Banner for iOS users
- App Store download links
- Information about the shared content
- Automatic app launch attempt via JavaScript

## Data Format

### Shared Data Structure
```json
[
  {
    "name": "张伟",
    "entries": [
      {"lang": "en-US", "text": "Ming Wang"},
      {"lang": "zh-CN", "text": "张伟"}
    ]
  }
]
```

### Encoding Process
1. JSON → String
2. String → Base64
3. Base64 → URL-safe Base64 (replace +/= with -_)
4. Append as `?s=` parameter

### Decoding Process (in app)
1. Extract `s` parameter
2. URL-safe Base64 → regular Base64
3. Base64 → Data
4. Data → JSON
5. JSON → NameEntry array

## Testing

### Test URLs
Create test URLs with sample data:
```swift
// In app, use DeepLinkBuilder.url(for: entries) to generate test URLs
let testEntries = [
    NameEntry(displayName: "Test Name", items: [
        LangItem(bcp47: "en-US", text: "Test Name"),
        LangItem(bcp47: "zh-CN", text: "测试名字")
    ])
]
let shareUrl = DeepLinkBuilder.url(for: testEntries)
```

### Manual Testing
1. **Simulator**: Test with custom scheme URLs
2. **Device**: Test with both custom scheme and HTTPS URLs
3. **Safari**: Test Smart App Banner functionality
4. **Share**: Test end-to-end sharing workflow

### Automated Testing
Consider adding unit tests for:
- URL parsing logic
- Base64 encoding/decoding
- JSON serialization/deserialization
- Error handling for malformed URLs

## Server Setup (Phoenix/Elixir)

### Route Configuration
Ensure Phoenix server responds to `saymyname.qingbo.us` domain:

```elixir
# In router.ex or appropriate route file
get "/", PageController, :index
get "/*path", PageController, :index  # Catch-all for client-side routing
```

### DNS Configuration
Set up DNS records:
```
saymyname.qingbo.us CNAME your-server.com
```

### SSL Certificate
Ensure HTTPS certificate covers `saymyname.qingbo.us` subdomain.

## Security Considerations

### URL Validation
- Always validate incoming URLs
- Check domain whitelist
- Sanitize Base64 input
- Validate JSON structure

### Data Size Limits
- Limit maximum shared list size
- Handle parsing errors gracefully
- Consider URL length limits (2048 chars in some browsers)

### Privacy
- Shared URLs contain pronunciation data
- Consider if sensitive names should have sharing restrictions
- No personal user data in URLs

## Troubleshooting

### Common Issues
1. **App doesn't open**: Check URL scheme registration
2. **Data not loading**: Verify Base64 encoding/decoding
3. **Smart App Banner not showing**: Check App Store ID and meta tags
4. **HTTPS not working**: Verify domain and SSL configuration

### Debug Tools
- Use Xcode debugger to inspect URL parsing
- Test URLs in Safari's address bar
- Use browser developer tools for web functionality
- Monitor Phoenix server logs for domain requests

## Future Enhancements

### Potential Features
- Universal Links (iOS 9+) instead of custom schemes
- Android deep linking support
- QR code generation for shared lists
- Short URL service integration
- Analytics for shared link usage

### App Store Requirements
- Document deep linking in App Store submission
- Include privacy information about shared data
- Test all deep linking scenarios before submission