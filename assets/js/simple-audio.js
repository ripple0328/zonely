// Minimal audio functionality for Phoenix LiveView
// Leverages browser APIs directly with minimal JavaScript

export function setupSimpleAudio() {
  let currentAudio = null;
  let cachedVoices = [];

  function refreshVoices() {
    try {
      const list = window.speechSynthesis ? window.speechSynthesis.getVoices() : [];
      if (Array.isArray(list) && list.length) cachedVoices = list;
    } catch (_) {}
  }

  function pickBestVoice(targetLang) {
    if (!('speechSynthesis' in window)) return null;
    refreshVoices();
    const voices = cachedVoices;
    if (!voices || !voices.length) return null;

    const base = (targetLang || '').split('-')[0] || '';

    // Rank voices by:
    // 1) exact lang match > base match > others
    // 2) name includes preferred vendor markers
    // 3) name includes Female/known pleasant voices
    const vendorHints = [/google/i, /enhanced/i, /natural/i, /neural/i, /premium/i];
    const pleasantHints = [/female/i, /samantha/i, /victoria/i, /amelie/i, /serena/i, /monica/i, /kyoko/i, /anna/i, /alice/i];

    const scored = voices.map(v => {
      let score = 0;
      if (v.lang === targetLang) score += 100;
      else if (base && v.lang && v.lang.toLowerCase().startsWith(base.toLowerCase())) score += 60;

      if (vendorHints.some(rx => rx.test(v.name))) score += 20;
      if (pleasantHints.some(rx => rx.test(v.name))) score += 10;
      // Prefer non-default voices slightly
      if (!v.default) score += 2;
      return { v, score };
    });

    scored.sort((a, b) => b.score - a.score);
    return (scored[0] && scored[0].v) || null;
  }

  // Audio file playback for both real person and AI-generated audio
  function handleAudioPlayback(event) {
    // Stop current audio if playing
    if (currentAudio) {
      currentAudio.pause();
      currentAudio.currentTime = 0;
    }

    // Stop speech synthesis if active  
    if ('speechSynthesis' in window) speechSynthesis.cancel();

    // Play new audio
    currentAudio = new Audio(event.detail.url);
    currentAudio.play().catch(console.error);
    currentAudio.onended = () => {
      currentAudio = null;
      // Notify LiveView that audio ended by dispatching a custom event that can be caught by hooks
      if (event.detail.user_id) {
        const endEvent = new CustomEvent('audio:ended', {
          detail: { user_id: event.detail.user_id }
        });
        document.dispatchEvent(endEvent);
      }
    };
  }

  // Register handlers for both real person and AI-generated audio
  window.addEventListener("phx:play_audio", handleAudioPlayback);
  window.addEventListener("phx:play_tts_audio", handleAudioPlayback);

  // Simple TTS using browser's built-in speech synthesis
  window.addEventListener("phx:play_tts", (event) => {
    const { text, lang } = event.detail;
    
    if (!('speechSynthesis' in window)) {
      console.warn('Speech synthesis not supported');
      return;
    }

    // Stop current audio/speech
    if (currentAudio) {
      currentAudio.pause();
      currentAudio.currentTime = 0;
      currentAudio = null;
    }
    speechSynthesis.cancel();
    
    // Create and configure utterance with tuned parameters
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = lang;
    // Slightly slower and fuller voice for clarity
    utterance.rate = 0.95;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;
    
    // Select a pleasant, natural-sounding voice for the requested language
    const voice = pickBestVoice(lang);
    if (voice) utterance.voice = voice;
    
    // Add event listener for when TTS ends
    utterance.onend = () => {
      // Notify LiveView that TTS ended
      if (event.detail.user_id) {
        const endEvent = new CustomEvent('audio:ended', {
          detail: { user_id: event.detail.user_id }
        });
        document.dispatchEvent(endEvent);
      }
    };
    
    speechSynthesis.speak(utterance);
  });

  // Minimal voice loading - let browser handle it
  if ('speechSynthesis' in window) {
    // Preload voices list and keep it refreshed
    refreshVoices();
    speechSynthesis.onvoiceschanged = () => {
      refreshVoices();
    };
  }

  // Create a hook to listen for audio end events and push them to LiveView
  window.AudioHook = {
    mounted() {
      this.handleAudioEnd = (e) => {
        this.pushEvent("audio_ended", { user_id: e.detail.user_id });
      };
      document.addEventListener('audio:ended', this.handleAudioEnd);
    },
    destroyed() {
      document.removeEventListener('audio:ended', this.handleAudioEnd);
    }
  };
}