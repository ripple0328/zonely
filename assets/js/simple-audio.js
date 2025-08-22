// Minimal audio functionality for Phoenix LiveView
// Following Phoenix best practices: keep JS minimal, server does the work

export function setupSimpleAudio() {
  // Simple audio playback - just HTML5 audio
  window.addEventListener("phx:play_audio", (event) => {
    const { url } = event.detail;
    const audio = new Audio(url);
    audio.play().catch(console.error);
  });

  // Simple TTS - just browser SpeechSynthesis API without complex logic
  window.addEventListener("phx:speak_simple", (event) => {
    const { text, lang } = event.detail;
    
    if ('speechSynthesis' in window) {
      // Cancel any current speech
      speechSynthesis.cancel();
      
      // Create and speak utterance
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = lang;
      speechSynthesis.speak(utterance);
    }
  });

  console.log('✅ Simple audio system initialized');
}
