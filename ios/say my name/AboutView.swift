import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon placeholder
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .padding(.top, 32)
                
                Text("SayMyName")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Hear any name pronounced correctly")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    aboutItem(icon: "globe", title: "Multi-language Support", description: "Pronunciations in 50+ languages and dialects")
                    
                    aboutItem(icon: "bolt.fill", title: "Fast & Accurate", description: "AI-powered text-to-speech with natural voices")
                    
                    aboutItem(icon: "lock.shield", title: "Privacy First", description: "Names are never stored permanently")
                    
                    aboutItem(icon: "icloud", title: "Offline Cache", description: "Previously heard names work offline")
                }
                .padding(.horizontal)
                
                Spacer()
                
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func aboutItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

