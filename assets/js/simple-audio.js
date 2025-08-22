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

  // Get the best voice for a given language, prioritizing natural-sounding voices
  function getBestVoice(lang) {
    if (!voicesLoaded || availableVoices.length === 0) {
      return null;
    }

    const langPrefix = lang.split('-')[0];
    
    // Prefer local voices for better quality and responsiveness
    const localVoices = availableVoices.filter(voice => voice.localService);
    
    // Look for high-quality voice names (these tend to sound more natural)
    const preferredVoiceNames = [
      'Samantha', 'Alex', 'Victoria', 'Daniel', 'Karen', 'Moira', 'Tessa',
      'Ava', 'Allison', 'Susan', 'Vicki', 'Princess', 'Veena', 'Fiona'
    ];

    // Try to find preferred voices first (local)
    for (const voiceName of preferredVoiceNames) {
      const voice = localVoices.find(v => 
        v.name.includes(voiceName) && 
        (v.lang === lang || v.lang.startsWith(langPrefix))
      );
      if (voice) {
        console.log(`🎤 Found preferred local voice: ${voice.name} (${voice.lang})`);
        return voice;
      }
    }

    // Try local voices with exact language match
    let voice = localVoices.find(v => v.lang === lang);
    if (voice) return voice;

    // Try local voices with language prefix match
    voice = localVoices.find(v => v.lang.startsWith(langPrefix));
    if (voice) return voice;

    // Fallback to any voice with exact language match
    voice = availableVoices.find(v => v.lang === lang);
    if (voice) return voice;

    // Fallback to any voice with language prefix match
    voice = availableVoices.find(v => v.lang.startsWith(langPrefix));
    if (voice) return voice;

    // Final fallback to first available voice
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
      
      // Create utterance with friendly, natural settings
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = lang;
      utterance.rate = 0.85;   // Slightly slower for warmth and clarity
      utterance.pitch = 1.1;   // Slightly higher pitch for friendliness
      utterance.volume = 0.9;  // Clear, confident volume
      
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