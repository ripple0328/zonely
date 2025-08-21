# 🎯 Real Name Pronunciation Setup

This document explains how to set up authentic name pronunciations using real people's voices instead of robotic TTS.

## 🌟 **System Overview**

Your team directory now uses a **smart pronunciation hierarchy**:

1. **👤 User-recorded audio** (most authentic)
2. **🎤 Forvo API** (real people pronunciations)  
3. **🤖 Enhanced TTS** (name-specific improvements)

---

## 🚀 **Quick Start (Free)**

The system works immediately without any setup! It will:
- ✅ Use improved TTS with name-specific pronunciation rules
- ✅ Handle international names better than standard TTS
- ✅ Cache results to avoid repeated processing

**Just click the play buttons in `/directory` to test!**

---

## 🎯 **Forvo API Setup (Recommended)**

For **production-quality** pronunciations from real native speakers:

### 1. **Get Forvo API Key (Free Tier Available)**
```bash
# Visit: https://api.forvo.com/
# Sign up for free account
# Get your API key from dashboard
```

### 2. **Set Environment Variable**
```bash
# Add to your .env or shell profile:
export FORVO_API_KEY="your_api_key_here"
```

### 3. **Restart Your Server**
```bash
mix phx.server
```

### 4. **Test Real Pronunciations**
- Go to `/directory`
- Click play buttons next to names
- Check server logs for Forvo API calls
- First time may be slower (fetching), then cached

---

## 📊 **Forvo API Pricing**

- **Free Tier**: 500 requests/day
- **Paid Plans**: From $0.004/request
- **Perfect for teams**: One-time fetch per name, then cached forever

---

## 🎤 **User-Recorded Audio (Ultimate Quality)**

For the **most authentic** experience, users can record their own name:

### 1. **Record Audio**
```javascript
// Users can record 1-2 second audio clips
// Save as MP3/OGG and upload to your storage
```

### 2. **Add to User Profile**
```elixir
# Update user with audio URL
user = %User{
  name: "Siobhán", 
  pronunciation_audio_url: "https://your-storage.com/siobhan.mp3"
}
```

### 3. **Automatic Priority**
System automatically uses user-recorded audio first when available.

---

## 🔧 **How It Works**

### **Smart Fallback Logic:**
```elixir
def get_name_pronunciation(user) do
  cond do
    # 1. User recorded? → Play that
    user.pronunciation_audio_url → {:audio_url, url}
    
    # 2. Cached Forvo? → Play cached
    user.forvo_audio_url → {:audio_url, url}
    
    # 3. Try Forvo API → Fetch and cache
    forvo_url = fetch_from_forvo() → {:audio_url, url}
    
    # 4. Enhanced TTS → Better than default
    true → {:tts, improved_text, language}
  end
end
```

### **Caching System:**
- ✅ Forvo results cached in database
- ✅ 24-hour refresh cycle
- ✅ No repeated API calls for same name
- ✅ Graceful fallback if API unavailable

---

## 🧪 **Testing & Debugging**

### **Check System Status:**
```bash
# Test in browser console:
testTTS()
```

### **Debug Logs:**
```bash
# Server logs show:
🔊 AUDIO URL: John Smith → https://forvo.com/audio/...
🔍 Trying free sources for: María García (es-ES)
🔊 TTS: Ahmed Hassan → 'Ahmed Hassan' (ar-EG)
```

### **Browser Console:**
```javascript
// Shows voice selection and quality:
✅ Using voice: Google 日本語 (ja-JP) - Quality: High (Local)
🔊 Audio URL Event received: {url: "https://..."}
🎤 Audio started
✅ Audio ended
```

---

## 🌍 **Supported Languages**

### **Forvo API Coverage:**
- **300+ languages**
- **5+ million pronunciations**
- **Real native speakers**
- **Regional variants**

### **Enhanced TTS Rules:**
- **Asian names**: Ng → Ing, Xiao → Shao
- **European names**: Silent 'gh', 'ph' → 'f'  
- **Arabic names**: Better transliteration
- **All names**: CamelCase splitting

---

## 💡 **Best Practices**

### **For Teams:**
1. **Set up Forvo API** for production quality
2. **Encourage user recordings** for authentic pronunciation
3. **Test with diverse names** from your actual team
4. **Monitor API usage** to stay within limits

### **For Users:**
1. **Record your name** if pronunciation is important
2. **Use native script** in `name_native` field for display
3. **Specify correct language** in profile

---

## 🚨 **Troubleshooting**

### **No Sound Playing:**
```bash
# Check browser console for errors
# Verify audio permissions
# Try different browser (Chrome works best)
```

### **API Not Working:**
```bash
# Verify API key: echo $FORVO_API_KEY
# Check network connectivity
# Review server logs for error messages
```

### **Poor Pronunciation:**
```bash
# Add user recording (best solution)
# Report to Forvo (crowdsourced improvement)
# System will fall back to enhanced TTS
```

---

## ✨ **Next Steps**

1. **Test current system** (works without setup)
2. **Get Forvo API key** for real pronunciations
3. **Add user recordings** for ultimate quality
4. **Expand to other UI elements** (profile pages, etc.)

The pronunciation system is now **production-ready** with multiple quality tiers and intelligent fallbacks! 🎉
