import SwiftUI

struct PrivacyView: View {
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
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.blue.opacity(0.8))
                            .symbolRenderingMode(.hierarchical)

                        Text("Privacy Policy")
                            .font(.largeTitle.bold())

                        Text("Last updated: January 2025")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)

                    // Intro
                    privacyCard(icon: "hand.raised.fill", title: "Overview") {
                        Text("Say my name helps you hear name pronunciations in multiple languages. We collect minimal data to provide and improve the service.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Information We Collect
                    privacyCard(icon: "doc.text.fill", title: "Information We Collect") {
                        VStack(alignment: .leading, spacing: 8) {
                            bulletItem("Names and language selections are encoded in the page URL on your device. We also collect **hashed** (irreversible) versions of names for anonymous popularity metrics — the original names cannot be recovered.")
                            bulletItem("When you press play, we may fetch audio from third-party providers to deliver pronunciations.")
                            bulletItem("Server logs may include standard request metadata (IP address, user-agent) for reliability and security.")
                            bulletItem("We collect privacy-safe analytics data to understand how the service is used.")
                        }
                    }

                    // How We Use Information
                    privacyCard(icon: "gearshape.2.fill", title: "How We Use Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            bulletItem("To serve audio pronunciations.")
                            bulletItem("To operate, maintain, and secure the service.")
                            bulletItem("To measure usage patterns and improve the service through anonymous analytics.")
                        }
                    }

                    // Analytics
                    privacyCard(icon: "chart.bar.fill", title: "Analytics") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("All analytics data is designed to be privacy-safe — we do not collect personally identifiable information (PII).")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            bulletItem("**Name hashes** — names are transformed using SHA-256 before storage. The original name cannot be recovered.")
                            bulletItem("**Country code** — we record your country (e.g. \"US\", \"GB\") for geographic trends. No IP address, city, or precise location is stored.")
                            bulletItem("**Hashed user agent** — your browser's user-agent is truncated and hashed, used solely for bot detection.")
                            bulletItem("**Referrer domain** — if you arrive from another site, we record only the domain name, not the full URL.")
                            bulletItem("**Session ID** — a temporary, randomly generated identifier to group actions within a single visit. Not linked to your identity.")
                            bulletItem("**Events and language selections** — we record which features are used and which languages are selected.")
                        }
                    }

                    // Third-Party Services
                    privacyCard(icon: "arrow.triangle.branch", title: "Third-Party Services") {
                        Text("To provide pronunciations, we query third-party services (e.g. pronunciation databases or text-to-speech). We share only what's needed to retrieve audio, such as a name and language code.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Data Retention
                    privacyCard(icon: "clock.fill", title: "Data Retention") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your list of names is stored only in the page URL on your device.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            bulletItem("We cache AI-generated pronunciation audio (text-to-speech) on our servers to improve performance. We **do not** cache human voice recordings from external providers due to licensing.")
                            bulletItem("Anonymous analytics data is retained for 90–180 days depending on event type, then automatically deleted.")
                            bulletItem("Standard server logs are retained for a limited period for operational purposes.")
                        }
                    }

                    // Your Choices
                    privacyCard(icon: "hand.tap.fill", title: "Your Choices") {
                        VStack(alignment: .leading, spacing: 8) {
                            bulletItem("Do not share URLs that contain names if you consider them sensitive.")
                            bulletItem("Clear your browser history or cookies to remove saved state.")
                        }
                    }

                    // Contact
                    privacyCard(icon: "envelope.fill", title: "Contact") {
                        Text("Questions or requests? Email [saymyname@qingbo.us](mailto:saymyname@qingbo.us).")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyCard<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func bulletItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(.blue.opacity(0.6))
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

