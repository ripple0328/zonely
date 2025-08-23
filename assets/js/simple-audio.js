// Minimal audio functionality for Phoenix LiveView
// Leverages browser APIs directly with minimal JavaScript

export function setupSimpleAudio() {
  let currentAudio = null;

  // Simple audio file playback using Phoenix events
  window.addEventListener("phx:play_audio", (event) => {
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
    currentAudio.onended = () => currentAudio = null;
  });

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
    
    // Create and configure utterance using browser defaults
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = lang;
    utterance.rate = 0.9;    // Natural speaking pace
    utterance.pitch = 1.0;   // Natural pitch
    utterance.volume = 0.9;  // Audible volume
    
    // Use browser's default voice selection for language
    const voices = speechSynthesis.getVoices();
    const voice = voices.find(v => v.lang === lang || v.lang.startsWith(lang.split('-')[0]));
    if (voice) utterance.voice = voice;
    
    speechSynthesis.speak(utterance);
  });

  // Minimal voice loading - let browser handle it
  if ('speechSynthesis' in window) {
    speechSynthesis.onvoiceschanged = () => {
      // Browser handles voice loading automatically
    };
  }
}