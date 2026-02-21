import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Hero section
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)
                            .padding(.top, 8)

                        Text("SayMyName")
                            .font(.largeTitle.bold())

                        Text("Hear any name pronounced correctly")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // How It Works
                    aboutSection(icon: "waveform.path", title: "How It Works") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("We search multiple crowd-sourced databases for **real-person pronunciations** and use AI only as a last resort.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("We do not cache provider audio on our servers due to licensing.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("**Why sometimes only first name:** if a full name isn't found but a real voice for the first name is available, we play the first name. If only the last name is found, we don't mix it with AI for consistency — so we fall back instead.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Key features
                    aboutCard(
                        icon: "person.wave.2.fill",
                        title: "Real Human Voices",
                        description: "Pronunciations from real people via NameShouts and Forvo. AI is only used as a fallback."
                    )

                    aboutCard(
                        icon: "lock.shield.fill",
                        title: "Privacy First",
                        description: "Names are never stored permanently. Only hashed for anonymous popularity metrics."
                    )

                    // Acknowledgments
                    aboutSection(icon: "heart.fill", title: "Acknowledgments") {
                        Text("Name pronunciations powered by [NameShouts](https://www.nameshouts.com/) and [Forvo](https://forvo.com/).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Contact
                    aboutSection(icon: "envelope.fill", title: "Contact") {
                        Text("Questions or feedback? Email [saymyname@qingbo.us](mailto:saymyname@qingbo.us).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Version footer
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
                .padding(16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func aboutSection<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

