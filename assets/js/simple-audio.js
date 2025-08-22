// Enhanced audio functionality for Phoenix LiveView
// Following Phoenix best practices: keep JS minimal, server does the work

export function setupSimpleAudio() {
  let currentAudio = null;
  let availableVoices = [];
  let voicesLoaded = false;

  // Load available voices
  function loadVoices() {
    availableVoices = speechSynthesis.getVoices();
    voicesLoaded = true;
    console.log('🎤 Available TTS voices:', availableVoices.length);
  }

  // Get the best voice for a given language
  function getBestVoice(lang) {
    if (!voicesLoaded || availableVoices.length === 0) {
      return null;
    }

    // Language code mapping for better voice selection
    const langMap = {
      'en-US': ['en-US', 'en'],
      'en-GB': ['en-GB', 'en'],
      'en-AU': ['en-AU', 'en'],
      'en-CA': ['en-CA', 'en'],
      'es-ES': ['es-ES', 'es'],
      'es-MX': ['es-MX', 'es'],
      'fr-FR': ['fr-FR', 'fr'],
      'de-DE': ['de-DE', 'de'],
      'it-IT': ['it-IT', 'it'],
      'pt-PT': ['pt-PT', 'pt'],
      'pt-BR': ['pt-BR', 'pt'],
      'ja-JP': ['ja-JP', 'ja'],
      'zh-CN': ['zh-CN', 'zh'],
      'ko-KR': ['ko-KR', 'ko'],
      'hi-IN': ['hi-IN', 'hi'],
      'ar-EG': ['ar-EG', 'ar'],
      'sv-SE': ['sv-SE', 'sv']
    };

    const searchLangs = langMap[lang] || [lang, lang.split('-')[0]];
    
    // Try to find the best voice for the language
    for (const searchLang of searchLangs) {
      // First, try to find a voice that exactly matches the language
      const exactMatch = availableVoices.find(voice => 
        voice.lang === searchLang && voice.localService
      );
      if (exactMatch) {
        console.log(`🎯 Found exact local voice for ${lang}: ${exactMatch.name}`);
        return exactMatch;
      }

      // Then try any voice that matches the language (including cloud voices)
      const langMatch = availableVoices.find(voice => 
        voice.lang === searchLang
      );
      if (langMatch) {
        console.log(`🎯 Found voice for ${lang}: ${langMatch.name}`);
        return langMatch;
      }

      // Try partial matches (e.g., 'en' for 'en-US')
      const partialMatch = availableVoices.find(voice => 
        voice.lang.startsWith(searchLang)
      );
      if (partialMatch) {
        console.log(`🎯 Found partial voice match for ${lang}: ${partialMatch.name}`);
        return partialMatch;
      }
    }

    // Fallback to default voice
    console.log(`⚠️ No specific voice found for ${lang}, using default`);
    return availableVoices[0] || null;
  }

  // Simple audio playback - just HTML5 audio with better error handling
  window.addEventListener("phx:play_audio", (event) => {
    console.log('🔊 Play Audio Event:', event.detail);
    const { url } = event.detail;

    // Stop any currently playing audio
    if (currentAudio) {
      currentAudio.pause();
      currentAudio.currentTime = 0;
    }

    currentAudio = new Audio(url);
    currentAudio.play().catch(error => {
      console.error("Audio playback failed:", error);
      // Could potentially fall back to TTS here if audio fails
    });

    currentAudio.onended = () => {
      currentAudio = null;
    };
  });

  // Enhanced TTS with voice selection and better controls
  window.addEventListener("phx:speak_simple", (event) => {
    console.log('🔊 Speak Simple Event:', event.detail);
    const { text, lang } = event.detail;
    
    if ('speechSynthesis' in window) {
      // Cancel any current speech
      speechSynthesis.cancel();
      
      // Create utterance
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = lang;
      
      // Set voice if available
      const bestVoice = getBestVoice(lang);
      if (bestVoice) {
        utterance.voice = bestVoice;
        console.log(`🎤 Using voice: ${bestVoice.name} for language: ${lang}`);
      }
      
      // Enhanced speech settings for better quality
      utterance.rate = 0.9;    // Slightly slower for clarity
      utterance.pitch = 1.0;   // Normal pitch
      utterance.volume = 0.8;  // Slightly quieter to be less jarring
      
      // Error handling
      utterance.onerror = (event) => {
        console.error('TTS Error:', event.error);
      };
      
      utterance.onstart = () => {
        console.log(`🗣️ Started speaking: "${text}" in ${lang}`);
      };
      
      utterance.onend = () => {
        console.log(`✅ Finished speaking: "${text}"`);
      };
      
      speechSynthesis.speak(utterance);
    } else {
      console.warn('Speech synthesis not supported in this browser.');
    }
  });

  // Load voices when available
  if ('speechSynthesis' in window) {
    // Voices might not be loaded immediately
    speechSynthesis.onvoiceschanged = loadVoices;
    
    // Try to load voices immediately (some browsers have them ready)
    if (speechSynthesis.getVoices().length > 0) {
      loadVoices();
    }
  }

  console.log('✅ Enhanced audio system initialized');
}