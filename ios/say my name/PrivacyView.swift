import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Group {
                    Text("Last updated: January 2025")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("SayMyName is designed with privacy in mind. We collect minimal data to provide and improve our service.")
                    
                    Text("What We Collect")
                        .font(.headline)
                    
                    Text("• Name pronunciations (text input)\n• Language preferences\n• Anonymous usage analytics\n• Country-level location (from IP)")
                    
                    Text("How We Use Data")
                        .font(.headline)
                    
                    Text("• Generate audio pronunciations\n• Improve pronunciation quality\n• Understand usage patterns")
                    
                    Text("Data Retention")
                        .font(.headline)
                    
                    Text("Analytics data is retained for 90-180 days. Audio cache files are temporary.")
                    
                    Text("Your Rights")
                        .font(.headline)
                    
                    Text("You can request deletion of your data by contacting us.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

