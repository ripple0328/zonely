# App Store Release Checklist

## Pre-Submission Checklist

### ✅ Development Complete
- [x] App builds successfully in Release configuration
- [x] Bundle ID configured: `us.qingbo.saymyname`
- [x] Display name set: "Say My Name"  
- [x] Version set to 1.0, Build 1
- [x] Minimum iOS version: 16.0
- [x] App icons included (1024x1024 + variants)
- [x] Base URL configuration working (Debug/Release)
- [x] Info.plist configured with proper keys

### 📱 Testing Complete
- [ ] App tested on real iPhone device
- [ ] App tested on iPad (if supporting)
- [ ] All core features working:
  - [ ] Adding names
  - [ ] Playing pronunciations
  - [ ] Language selection
  - [ ] Audio caching
  - [ ] Share functionality
- [ ] Network connectivity handling
- [ ] Error handling for failed requests
- [ ] Performance testing (smooth scrolling, quick audio playback)

### 🔐 Apple Developer Setup
- [ ] Apple Developer Account active ($99/year)
- [ ] App ID created in Developer Console with bundle ID `us.qingbo.saymyname`
- [ ] Distribution certificate created
- [ ] App Store distribution provisioning profile created
- [ ] Code signing configured in Xcode

### 📸 Marketing Assets Ready
- [ ] App Store screenshots captured (see SCREENSHOTS_GUIDE.md)
  - [ ] iPhone 6.7" (1290 × 2796) - 3-5 screenshots
  - [ ] iPad 12.9" (2048 × 2732) - 3-5 screenshots (recommended)
- [ ] App Store description written (see APP_STORE_SUBMISSION.md)
- [ ] Keywords selected (under 100 characters)
- [ ] App category chosen: Education
- [ ] Age rating: 4+

### 🔒 Privacy & Legal
- [ ] Privacy policy created (if collecting any data)
- [ ] Terms of service (if needed)
- [ ] Copyright information ready
- [ ] Third-party licenses documented
- [ ] Export compliance determined (ITSAppUsesNonExemptEncryption = NO)

## App Store Connect Setup

### 1. Create App Record
- [ ] Log into https://appstoreconnect.apple.com
- [ ] Create new app:
  - **Name**: Say My Name
  - **Primary Language**: English (US)
  - **Bundle ID**: us.qingbo.saymyname
  - **SKU**: saymyname-2024 (or any unique identifier)

### 2. App Information
- [ ] **Name**: Say My Name
- [ ] **Subtitle**: Learn to pronounce names correctly
- [ ] **Categories**: 
  - Primary: Education
  - Secondary: Utilities
- [ ] **Content Rights**: Original or licensed content
- [ ] **Age Rating**: Complete questionnaire (should result in 4+)

### 3. Pricing and Availability  
- [ ] **Price**: Free (Tier 0)
- [ ] **Availability**: All countries and regions
- [ ] **App Distribution**: Available on App Store for iOS
- [ ] **Pre-orders**: No

### 4. App Privacy
- [ ] Complete privacy questionnaire
- [ ] **Data Collection**: No (if not collecting user data)
- [ ] **Data Usage**: Describe pronunciation service usage
- [ ] **Third-party SDK**: List any analytics or crash reporting

## Binary Upload Process

### 1. Archive in Xcode
- [ ] Select "Any iOS Device" as build target
- [ ] **Product** → **Archive**  
- [ ] Wait for archive to complete
- [ ] Xcode Organizer should open automatically

### 2. Upload to App Store Connect
- [ ] In Organizer, select your archive
- [ ] Click **Distribute App**
- [ ] Choose **App Store Connect**
- [ ] Select **Upload** (not Export)
- [ ] Follow prompts and wait for upload
- [ ] Verify upload appears in App Store Connect (may take 10-30 minutes)

### 3. Complete Version Information
- [ ] **What's New**: Version 1.0 description
- [ ] **Screenshots**: Upload all required screenshots
- [ ] **App Review Information**:
  - [ ] Contact information
  - [ ] Demo account (N/A - no login required)
  - [ ] Review notes (mention internet requirement)
- [ ] **Version Release**: Automatic release after approval

## Pre-Review Validation

### Final Testing
- [ ] Download TestFlight build and test on device
- [ ] Test all primary user flows
- [ ] Verify app works without crashes
- [ ] Check that all pronunciations play correctly
- [ ] Test with poor network conditions
- [ ] Verify sharing functionality works

### Content Review
- [ ] All text is professional and appropriate
- [ ] No placeholder content visible
- [ ] Sample names are culturally respectful
- [ ] No offensive or inappropriate content
- [ ] App description is accurate and not misleading

## Submission for Review

### Submit Process
- [ ] In App Store Connect, select your app version
- [ ] Click **Submit for Review**
- [ ] Answer all review questions:
  - [ ] Export compliance
  - [ ] Content rights
  - [ ] Advertising identifier usage
- [ ] Confirm submission

### Review Timeline
- [ ] Monitor email for review updates
- [ ] Typical review time: 1-3 business days
- [ ] Be prepared to respond to reviewer feedback
- [ ] Have contact information readily available

## Post-Approval

### Release Day
- [ ] App automatically releases (if set to automatic)
- [ ] Verify app appears in App Store
- [ ] Test download from App Store
- [ ] Share app link with friends/colleagues for initial reviews

### Monitoring
- [ ] Monitor App Store ratings and reviews
- [ ] Respond to user feedback professionally  
- [ ] Track download numbers in App Store Connect
- [ ] Monitor crash reports and user feedback
- [ ] Plan for future updates based on user feedback

## Emergency Procedures

### If Review is Rejected
- [ ] Read rejection reason carefully
- [ ] Fix issues mentioned by reviewer
- [ ] Update binary if code changes needed
- [ ] Resubmit with detailed notes about fixes
- [ ] Respond professionally to reviewer feedback

### Post-Launch Issues
- [ ] Monitor crash reports in App Store Connect
- [ ] Have hotfix process ready for critical bugs
- [ ] Prepare update timeline for non-critical issues
- [ ] Maintain server infrastructure (saymyname.qingbo.us)

## Contact Information Template

```
App Store Connect Review Team Contact:
- First Name: [Your First Name]
- Last Name: [Your Last Name]  
- Phone: [Your Phone Number]
- Email: [Your Email]

App Information:
- App Name: Say My Name
- Bundle ID: us.qingbo.saymyname
- Version: 1.0
- Primary Category: Education
- Server: saymyname.qingbo.us
```

## Success Metrics
- [ ] App approval within first submission
- [ ] No crashes reported in first week
- [ ] Positive initial user reviews (4+ stars)
- [ ] Successful pronunciation playback for users
- [ ] Server handling user load appropriately

---

**Remember**: This is your first App Store submission, so expect to learn from the process. Apple's review team provides helpful feedback if any issues arise.