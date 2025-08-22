// Simple inline audio functionality for Phoenix LiveView
// Server handles all the logic, client just plays the audio

export function setupSimpleAudio() {
  let currentAudio = null;
  let availableVoices = [];
  let voicesLoaded = false;

  // Load available voices for TTS
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

    // Prefer local voices, then find best match for language
    const localVoices = availableVoices.filter(voice => voice.localService);
    const allVoices = availableVoices;

    // Try local voices first, then all voices
    for (const voiceSet of [localVoices, allVoices]) {
      // Exact language match
      let voice = voiceSet.find(v => v.lang === lang);
      if (voice) return voice;

      // Language prefix match (e.g., 'en' for 'en-US')
      const langPrefix = lang.split('-')[0];
      voice = voiceSet.find(v => v.lang.startsWith(langPrefix));
      if (voice) return voice;
    }

    // Fallback to first available voice
    return availableVoices[0] || null;
  }

  // Play audio file inline
  window.addEventListener("phx:play_audio", (event) => {
    console.log('🔊 Playing audio file:', event.detail.url);
    
    // Stop any current audio
    if (currentAudio) {
      currentAudio.pause();
      currentAudio.currentTime = 0;
    }

    // Stop any current speech
    if ('speechSynthesis' in window) {
      speechSynthesis.cancel();
    }

    // Play the audio file
    currentAudio = new Audio(event.detail.url);
    currentAudio.play().catch(error => {
      console.error("Audio playback failed:", error);
    });

    currentAudio.onended = () => {
      currentAudio = null;
    };
  });

  // Play TTS inline with enhanced voice selection
  window.addEventListener("phx:play_tts", (event) => {
    const { text, lang } = event.detail;
    console.log('🗣️ Playing TTS:', text, 'in', lang);
    
    if ('speechSynthesis' in window) {
      // Stop any current audio or speech
      if (currentAudio) {
        currentAudio.pause();
        currentAudio.currentTime = 0;
        currentAudio = null;
      }
      speechSynthesis.cancel();
      
      // Create utterance with enhanced settings
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = lang;
      utterance.rate = 0.9;    // Slightly slower for clarity
      utterance.pitch = 1.0;   // Natural pitch
      utterance.volume = 0.8;  // Comfortable volume
      
      // Select the best voice
      const bestVoice = getBestVoice(lang);
      if (bestVoice) {
        utterance.voice = bestVoice;
        console.log(`🎤 Using voice: ${bestVoice.name} (${bestVoice.lang})`);
      }
      
      // Enhanced event handling
      utterance.onstart = () => {
        console.log(`🗣️ Started speaking: "${text}"`);
      };
      
      utterance.onend = () => {
        console.log(`✅ Finished speaking: "${text}"`);
      };
      
      utterance.onerror = (event) => {
        console.error('TTS Error:', event.error);
      };
      
      speechSynthesis.speak(utterance);
    } else {
      console.warn('Speech synthesis not supported in this browser.');
    }
  });

  // Load voices when available
  if ('speechSynthesis' in window) {
    speechSynthesis.onvoiceschanged = loadVoices;
    
    // Try to load voices immediately
    if (speechSynthesis.getVoices().length > 0) {
      loadVoices();
    }
  }

  console.log('✅ Simple inline audio system initialized');
}