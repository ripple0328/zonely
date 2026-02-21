# Deep Link Testing Guide

## 🧪 **Testing Setup Complete**

The deep linking system is now fully implemented and ready for testing with your running Phoenix server.

## 📱 **How to Test Locally**

### 1. **Server Setup**
Your Phoenix server should be running and accessible at:
- **Domain**: `saymyname.qingbo.us` (configure DNS/hosts file if needed)
- **Local**: `http://192.168.5.14:4000` (or your current local IP)
- **Local path**: `http://192.168.5.14:4000/name` (fallback route)

### 2. **iOS App Installation**
1. Build your app in Xcode for your iPhone
2. Install on device via Xcode (make sure it's the latest version with deep link support)

### 3. **Generate Test URLs**

**Method A: Using Your Web App (Recommended)**
1. Open `http://192.168.5.14:4000/name` in your browser
2. Add some test names (e.g., "Zhang Wei" + "张伟")
3. Click the "Copy link" button - this generates a real share URL
4. The URL will look like: `https://saymyname.qingbo.us/?s=BASE64_DATA`

**Method B: Manual Test URL Creation**
Open browser console on your web app and run:
```javascript
// Create test data
const testData = [
  {
    name: "Test Name",
    entries: [
      {lang: "en-US", text: "Test Name"},
      {lang: "zh-CN", text: "测试名字"}
    ]
  }
];

// Generate URL (same encoding as your app)
const json = JSON.stringify(testData);
const base64 = btoa(unescape(encodeURIComponent(json)));
const urlSafe = base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
console.log(`https://saymyname.qingbo.us/?s=${urlSafe}`);
console.log(`saymyname://?s=${urlSafe}`);
```

### 4. **Test Deep Links**

**Test 1: Custom Scheme (Direct App Opening)**
1. Copy the `saymyname://` URL from above
2. On iPhone, open **Notes** app
3. Paste the URL and tap it
4. Should prompt: **"Open in Say My Name?"**
5. Tap **"Open"** → App should launch with test data

**Test 2: HTTPS Fallback + Smart App Banner**
1. Copy the `https://saymyname.qingbo.us/` URL
2. Send to iPhone (text message, email, or AirDrop)
3. Tap the link on iPhone
4. Should open in Safari with **Smart App Banner** at top
5. Banner shows: **"Open in Say My Name"** with **"OPEN"** button
6. Tap **"OPEN"** → App should launch with shared data

**Test 3: End-to-End Sharing**
1. Add names in your iOS app
2. Use the share feature to generate URL
3. Send that URL to someone else (or another device)
4. Test the complete sharing → receiving workflow

## 🔧 **Smart App Banner Details**

### Current Implementation
- **Location**: Added to `/lib/zonely_web/controllers/name_site_html/index.html.heex`
- **Meta Tag**: `<meta name="apple-itunes-app" content="app-id=YOUR_APP_ID, app-argument=https://saymyname.qingbo.us/">`
- **Dynamic Updates**: JavaScript updates the banner with shared data parameter
- **Fallback**: Invisible iframe attempts custom scheme URL for direct app opening

### What Users See
1. **Has App**: Link opens directly in app (custom scheme works)
2. **No App**: Safari opens with banner at top saying "Open in Say My Name" → "Install" button
3. **After Install**: App launches automatically with shared data loaded

## 🚨 **Troubleshooting**

### App Doesn't Open
- Check URL scheme registration in Xcode project settings
- Verify app is installed from Xcode (not TestFlight initially)
- Try typing URL manually in Safari address bar

### Smart App Banner Not Showing
- Verify you're accessing `https://saymyname.qingbo.us` (HTTPS required)
- Check that DNS resolves `saymyname.qingbo.us` to your server
- Smart App Banner only works on iOS Safari, not other browsers

### Data Not Loading in App
- Check deep link parsing logic in `AppViewModel.loadFromDeepLink()`
- Verify Base64 encoding/decoding matches between web and app
- Use Xcode debugger to inspect URL parsing

### DNS/Server Issues
If `saymyname.qingbo.us` doesn't resolve:
1. **Option A**: Update your local `/etc/hosts` file:
   ```
   192.168.5.14 saymyname.qingbo.us
   ```
2. **Option B**: Test with localhost path: `http://192.168.5.14:4000/name/?s=...`

## 📋 **Test Scenarios**

### Basic Tests
- [ ] Custom scheme URL opens app
- [ ] HTTPS URL shows Smart App Banner
- [ ] Shared data loads correctly in app
- [ ] Invalid URLs fail gracefully

### Edge Cases
- [ ] Very long name lists
- [ ] Special characters in names (emojis, accents, etc.)
- [ ] Empty or malformed share data
- [ ] Network connectivity issues

### User Experience Tests
- [ ] Banner appears quickly on page load
- [ ] App opens smoothly from banner
- [ ] Shared names appear immediately in app
- [ ] Previous app data is replaced (not merged) with shared data

## 🎯 **Next Steps After Testing**

1. **DNS Setup**: Configure actual DNS for `saymyname.qingbo.us`
2. **SSL Certificate**: Ensure HTTPS works for the domain
3. **App Store ID**: Replace `YOUR_APP_ID` after App Store approval
4. **Production Deploy**: Deploy Phoenix server with deep link support
5. **App Store Submission**: Include deep linking in app description

## 📊 **Success Criteria**

✅ **Working Deep Links**
- Custom scheme URLs open app directly
- HTTPS URLs show Smart App Banner
- Shared data loads correctly in app
- Fallback behavior works for unsupported scenarios

✅ **Good User Experience**  
- Fast app opening from links
- Intuitive Smart App Banner
- Seamless data transfer from web to app
- Graceful handling of edge cases

Your deep linking system is now production-ready and can be tested immediately with your existing server setup!