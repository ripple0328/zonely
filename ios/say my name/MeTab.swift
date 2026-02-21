import SwiftUI

struct MeTab: View {
    @State private var nameCard: NameCard?
    private let persistence = NameCardPersistence()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // My Name Card section (matches web MeLive)
                        nameCardSection

                        // App section
                        VStack(spacing: 0) {
                            NavigationLink {
                                AboutView()
                            } label: {
                                menuRow(icon: "waveform.circle.fill", iconColor: .blue,
                                        title: NSLocalizedString("about_how_it_works", comment: "How It Works"))
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 52)

                            NavigationLink {
                                PrivacyView()
                            } label: {
                                menuRow(icon: "lock.shield.fill", iconColor: .blue,
                                        title: NSLocalizedString("privacy", comment: "Privacy"))
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 52)

                            Link(destination: URL(string: "mailto:saymyname@qingbo.us")!) {
                                menuRow(icon: "envelope.fill", iconColor: .blue,
                                        title: NSLocalizedString("send_feedback", comment: "Send Feedback"))
                            }

                            Divider().padding(.leading, 52)

                            Link(destination: URL(string: "https://\(AppConfig.websiteDomain)")!) {
                                menuRow(icon: "globe", iconColor: .indigo,
                                        title: NSLocalizedString("use_on_web", comment: "Use on Web"))
                            }
                        }
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
            .navigationTitle(NSLocalizedString("tab_me", comment: "Me"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { nameCard = persistence.restore() }
        }
    }

    // MARK: - Name Card Section (matches web MeLive card preview / CTA)

    private var nameCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("my_name_card", comment: ""))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if let card = nameCard, card.isSaved {
                // Card preview (matches web: initials + name + pronouns + language flags + Edit/Share)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        // Initials avatar
                        Text(card.initials)
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .frame(width: 48, height: 48)
                            .background(Color.blue.opacity(0.15), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            if !card.pronouns.isEmpty {
                                Text(card.pronouns)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    // Language flags
                    if !card.languageVariants.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(card.languageVariants) { variant in
                                Text(NameCardLanguages.flag(for: variant.language))
                                    .font(.title3)
                                    .accessibilityLabel(NameCardLanguages.label(for: variant.language))
                            }
                        }
                    }

                    // Edit / Share buttons
                    HStack(spacing: 10) {
                        NavigationLink {
                            NameCardView(card: card, onSave: { updated in
                                nameCard = updated
                            }, onDelete: {
                                nameCard = nil
                            })
                        } label: {
                            Label(NSLocalizedString("edit_card", comment: ""), systemImage: "pencil")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        ShareLink(item: buildShareText(card)) {
                            Label(NSLocalizedString("share", comment: ""), systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(.green, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.06)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
            } else {
                // Empty state CTA (matches web: "You haven't set up your card yet")
                VStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)

                    Text(NSLocalizedString("card_empty_title", comment: ""))
                        .font(.subheadline.weight(.medium))
                    Text(NSLocalizedString("card_empty_subtitle", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        NameCardView(onSave: { card in
                            nameCard = card
                        })
                    } label: {
                        Text(NSLocalizedString("set_up_now", comment: ""))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.06)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
            }
        }
    }

    private func buildShareText(_ card: NameCard) -> String {
        var lines = [card.displayName]
        if !card.pronouns.isEmpty { lines.append("(\(card.pronouns))") }
        if !card.role.isEmpty { lines.append(card.role) }
        if !card.languageVariants.isEmpty {
            lines.append("")
            for v in card.languageVariants {
                let flag = NameCardLanguages.flag(for: v.language)
                var line = "\(flag) \(v.name)"
                if !v.pronunciation.isEmpty { line += " (\(v.pronunciation))" }
                lines.append(line)
            }
        }
        lines.append("")
        lines.append("Shared via SayMyName — https://\(AppConfig.websiteDomain)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Menu Row

    private func menuRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

