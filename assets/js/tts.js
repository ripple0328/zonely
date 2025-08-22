// Text-to-speech functionality with enhanced voice selection
export class TextToSpeech {
  constructor() {
    this.currentAudio = null;
    this.init();
  }

  init() {
    // Load voices when available
    if ('speechSynthesis' in window) {
      window.speechSynthesis.onvoiceschanged = () => {
        const voices = window.speechSynthesis.getVoices();
        console.log(`🔄 Voices loaded: ${voices.length} available`);
      };
      
      console.log('🔊 TTS system initialized.');
    }
  }

  // Main TTS function with enhanced voice selection
  speak(text, lang, rate = 0.8, pitch = 1.0) {
    console.log(`🎵 Speaking: "${text}" in ${lang} (rate: ${rate}, pitch: ${pitch})`);
    
    if (!('speechSynthesis' in window)) {
      console.warn('❌ Speech synthesis not supported in this browser');
      alert(`Would speak: "${text}" in ${lang} (TTS not supported)`);
      return;
    }

    try {
      // Cancel any ongoing speech
      window.speechSynthesis.cancel();
      
      // Function to actually speak
      const doSpeak = () => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.lang = lang;
        
        // Enhanced parameters for English pronunciation
        const isEnglish = lang.startsWith('en');
        if (isEnglish) {
          // Optimized settings for English names and clarity
          utterance.rate = Math.max(0.85, rate);  // Slightly slower for clarity
          utterance.pitch = Math.min(1.1, pitch); // Slightly higher pitch for better clarity
          utterance.volume = 1.0;                  // Full volume
          console.log('🎯 Using enhanced English TTS settings');
        } else {
          // Use provided settings for other languages
          utterance.rate = rate;
          utterance.pitch = pitch;
          utterance.volume = 1.0;
        }
        
        // Get available voices
        const voices = window.speechSynthesis.getVoices();
        console.log(`🔍 Available voices: ${voices.length}`);
        
        if (voices.length === 0) {
          console.warn('⚠️ No voices loaded yet, speaking anyway...');
        }
        
        // Enhanced voice selection logic
        let voice = this.selectBestVoice(voices, lang);
        
        if (voice) {
          console.log(`✅ Using voice: ${voice.name} (${voice.lang}) - Quality: ${voice.localService ? 'High (Local)' : 'Network'}`);
          utterance.voice = voice;
          
          // Additional voice-specific optimizations
          if (isEnglish && voice.localService) {
            // For high-quality English voices, fine-tune parameters
            utterance.rate = Math.min(utterance.rate, 0.9); // Don't go too fast
            console.log('🔧 Applied local English voice optimizations');
          }
        } else {
          console.log(`⚠️ No specific voice found for ${lang}, using default`);
        }
        
        utterance.onstart = () => console.log('🎤 Speech started');
        utterance.onend = () => console.log('✅ Speech ended');
        utterance.onerror = (e) => {
          console.error('❌ Speech error:', e);
          alert(`Speech error: ${e.error} - "${text}"`);
        };
        
        console.log(`🚀 About to speak with rate: ${utterance.rate}, pitch: ${utterance.pitch}`);
        window.speechSynthesis.speak(utterance);
        
        // Fallback for some browsers
        setTimeout(() => {
          if (window.speechSynthesis.speaking) {
            console.log('✅ Speech is playing');
          } else {
            console.warn('⚠️ Speech may not be playing');
          }
        }, 500);
      };
      
      // Wait a bit for cancellation to complete, then speak
      setTimeout(doSpeak, 100);
      
    } catch (error) {
      console.error('❌ TTS Error:', error);
      alert(`TTS Error: ${error.message}`);
    }
  }

  // Better voice selection function with enhanced English support
  selectBestVoice(voices, targetLang) {
    if (!voices.length) return null;
    
    const langPrefix = targetLang.split('-')[0];
    const isEnglish = langPrefix === 'en';
    
    // Special handling for English voices
    if (isEnglish) {
      return this.selectBestEnglishVoice(voices, targetLang);
    }
    
    // Priority order for non-English voice selection
    const voicePreferences = [
      // 1. Exact language match + local/high quality
      v => v.lang === targetLang && v.localService,
      // 2. Exact language match + premium quality indicators
      v => v.lang === targetLang && (v.name.includes('Premium') || v.name.includes('Neural') || v.name.includes('HD')),
      // 3. Exact language match
      v => v.lang === targetLang,
      // 4. Language prefix match + local/high quality  
      v => v.lang.startsWith(langPrefix) && v.localService,
      // 5. Language prefix match + premium quality
      v => v.lang.startsWith(langPrefix) && (v.name.includes('Premium') || v.name.includes('Neural') || v.name.includes('HD')),
      // 6. Any language prefix match
      v => v.lang.startsWith(langPrefix),
      // 7. Default voice
      v => v.default
    ];
    
    for (const preference of voicePreferences) {
      const voice = voices.find(preference);
      if (voice) {
        return voice;
      }
    }
    
    return voices[0]; // Fallback to first available voice
  }

  // Specialized English voice selection for highest quality
  selectBestEnglishVoice(voices, targetLang) {
    console.log('🎯 Selecting best English voice from', voices.length, 'available voices');
    
    // Filter English voices
    const englishVoices = voices.filter(v => v.lang.startsWith('en'));
    
    if (!englishVoices.length) {
      console.warn('⚠️ No English voices found, using fallback');
      return voices[0];
    }
    
    console.log(`🔍 Found ${englishVoices.length} English voices:`, 
                englishVoices.map(v => `${v.name} (${v.lang}) ${v.localService ? '[Local]' : '[Network]'}`));
    
    // Premium English voice preferences (highest quality first)
    const englishPreferences = [
      // 1. High-quality branded voices (Siri, Google, Microsoft)
      v => v.localService && (v.name.includes('Samantha') || v.name.includes('Alex') || v.name.includes('Victoria')),
      // 2. Premium/Neural English voices
      v => v.localService && (v.name.includes('Premium') || v.name.includes('Neural') || v.name.includes('Enhanced')),
      // 3. Local system voices (macOS/Windows built-in)
      v => v.localService && (v.name.includes('System') || v.name.includes('Daniel') || v.name.includes('Karen')),
      // 4. Any local English voice
      v => v.localService,
      // 5. Google/Chrome premium voices
      v => v.name.includes('Google') && (v.name.includes('US') || v.name.includes('UK')),
      // 6. Exact target language match (en-US, en-GB, etc.)
      v => v.lang === targetLang,
      // 7. Any US English voice
      v => v.lang === 'en-US',
      // 8. Any UK English voice  
      v => v.lang === 'en-GB',
      // 9. Any English voice
      v => v.lang.startsWith('en'),
      // 10. Fallback to default
      v => v.default
    ];
    
    for (const preference of englishPreferences) {
      const voice = englishVoices.find(preference);
      if (voice) {
        console.log(`✅ Selected English voice: ${voice.name} (${voice.lang}) [${voice.localService ? 'Local' : 'Network'}]`);
        return voice;
      }
    }
    
    // Final fallback
    const fallback = englishVoices[0];
    console.log(`🔄 Using fallback English voice: ${fallback.name} (${fallback.lang})`);
    return fallback;
  }

  // Play audio from URL (for pre-recorded name pronunciations)
  playAudioUrl(url) {
    console.log(`🎵 Playing audio from URL: ${url}`);
    
    try {
      // Stop any current TTS
      if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
      }
      
      // Stop any current audio
      if (this.currentAudio) {
        this.currentAudio.pause();
        this.currentAudio.currentTime = 0;
        this.currentAudio = null;
      }
      
      // Wait a moment to ensure cleanup, then create and play new audio
      setTimeout(() => {
        const audio = new Audio(url);
        this.currentAudio = audio;
      
        audio.onloadstart = () => console.log('🔄 Loading audio...');
        audio.oncanplay = () => console.log('✅ Audio ready to play');
        audio.onplay = () => console.log('🎤 Audio started');
        audio.onended = () => {
          console.log('✅ Audio ended');
          this.currentAudio = null;
        };
        audio.onerror = (e) => {
          console.error('❌ Audio error:', e);
          this.currentAudio = null;
          alert(`Could not play audio from: ${url}`);
        };
        
        // Play the audio
        audio.play().catch(error => {
          console.error('❌ Audio play failed:', error);
          this.currentAudio = null;
          alert(`Audio playback failed: ${error.message}`);
        });
      }, 150); // Small delay to prevent conflicts
      
    } catch (error) {
      console.error('❌ Audio URL Error:', error);
      alert(`Audio URL Error: ${error.message}`);
    }
  }

  // Test function for debugging
  test() {
    console.log('🧪 Testing TTS...');
    this.speak('Hello World', 'en-US');
  }
}

// Export a default instance
export const tts = new TextToSpeech();
