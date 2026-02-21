import SwiftUI

struct NameCardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var pronouns: String
    @State private var role: String
    @State private var languageVariants: [LanguageVariant]
    @State private var showAddLanguage = false
    @State private var showShareSheet = false
    @State private var showDeleteConfirm = false

    private let persistence = NameCardPersistence()
    private let isEditing: Bool
    var onSave: ((NameCard) -> Void)?
    var onDelete: (() -> Void)?

    init(card: NameCard? = nil, onSave: ((NameCard) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        let c = card ?? NameCard()
        _displayName = State(initialValue: c.displayName)
        _pronouns = State(initialValue: c.pronouns)
        _role = State(initialValue: c.role)
        _languageVariants = State(initialValue: c.languageVariants)
        self.isEditing = card?.isSaved ?? false
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    formSection
                    languageSection
                    actionButtons
                }
                .padding(16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(isEditing ? NSLocalizedString("edit_name_card", comment: "") : NSLocalizedString("create_name_card", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(NSLocalizedString("share", comment: ""))
                }
            }
        }
        .sheet(isPresented: $showAddLanguage) {
            AddLanguageSheet(existingCodes: languageVariants.map(\.language)) { variant in
                languageVariants.append(variant)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            shareSheet
        }
        .alert(NSLocalizedString("delete_card_title", comment: ""), isPresented: $showDeleteConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) { deleteCard() }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("delete_card_message", comment: ""))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("name_card_subtitle", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Form Fields

    private var formSection: some View {
        VStack(spacing: 16) {
            // Display Name (required)
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("your_name", comment: ""))
                    .font(.subheadline.weight(.semibold))
                TextField(NSLocalizedString("name_card_name_placeholder", comment: ""), text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityLabel(NSLocalizedString("your_name", comment: ""))
            }

            HStack(spacing: 12) {
                // Pronouns (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("pronouns_label", comment: ""))
                        .font(.subheadline.weight(.semibold))
                    TextField(NSLocalizedString("pronouns_placeholder", comment: ""), text: $pronouns)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }

                // Role (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("role_label", comment: ""))
                        .font(.subheadline.weight(.semibold))
                    TextField(NSLocalizedString("role_placeholder", comment: ""), text: $role)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
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
    }

    // MARK: - Language Variants

    private var languageSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(NSLocalizedString("name_in_other_languages", comment: ""))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    showAddLanguage = true
                } label: {
                    Label(NSLocalizedString("add_language", comment: ""), systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .accessibilityLabel(NSLocalizedString("add_language", comment: ""))
            }

            if languageVariants.isEmpty {
                emptyLanguageState
            } else {
                ForEach(languageVariants) { variant in
                    languageRow(variant)
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
    }

    private var emptyLanguageState: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("no_language_variants", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func languageRow(_ variant: LanguageVariant) -> some View {
        HStack(spacing: 12) {
            Text(NameCardLanguages.flag(for: variant.language))
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(variant.name)
                    .font(.body.weight(.medium))
                if !variant.pronunciation.isEmpty {
                    Text("(\(variant.pronunciation))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(NameCardLanguages.label(for: variant.language))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                languageVariants.removeAll { $0.id == variant.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("remove", comment: ""))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Action Buttons & Logic

extension NameCardView {
    var actionButtons: some View {
        VStack(spacing: 12) {
            // Save button
            Button {
                saveCard()
            } label: {
                Label(NSLocalizedString("save_name_card", comment: ""), systemImage: "checkmark")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!canSave)
            .accessibilityLabel(NSLocalizedString("save_name_card", comment: ""))

            // Delete button (only if editing)
            if isEditing {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text(NSLocalizedString("delete_card_action", comment: ""))
                        .font(.subheadline)
                }
                .accessibilityLabel(NSLocalizedString("delete_card_action", comment: ""))
            }
        }
    }

    private func saveCard() {
        let card = NameCard(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            pronouns: pronouns.trimmingCharacters(in: .whitespaces),
            role: role.trimmingCharacters(in: .whitespaces),
            languageVariants: languageVariants,
            createdAt: Date()
        )
        persistence.store(card)
        onSave?(card)
        dismiss()
    }

    private func deleteCard() {
        persistence.delete()
        onDelete?()
        dismiss()
    }

    private var shareSheet: some View {
        let text = buildShareText()
        return ShareLink(item: text) {
            Text(NSLocalizedString("share_name_card", comment: ""))
        }
        .presentationDetents([.medium])
    }

    private func buildShareText() -> String {
        var lines = [displayName]
        if !pronouns.isEmpty { lines.append("(\(pronouns))") }
        if !role.isEmpty { lines.append(role) }
        if !languageVariants.isEmpty {
            lines.append("")
            for v in languageVariants {
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
}

// MARK: - Add Language Sheet

struct AddLanguageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existingCodes: [String]
    let onAdd: (LanguageVariant) -> Void

    @State private var selectedCode: String = "zh-CN"
    @State private var name: String = ""
    @State private var pronunciation: String = ""

    private var availableLanguages: [SupportedLanguage] {
        NameCardLanguages.all.filter { !existingCodes.contains($0.code) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Language picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("language", comment: ""))
                                .font(.subheadline.weight(.semibold))
                            Picker(NSLocalizedString("language", comment: ""), selection: $selectedCode) {
                                ForEach(availableLanguages) { lang in
                                    Text("\(lang.flag) \(lang.label)")
                                        .tag(lang.code)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 150)
                        }

                        // Name in language
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("name_in_language", comment: ""))
                                .font(.subheadline.weight(.semibold))
                            TextField(NSLocalizedString("name_native_placeholder", comment: ""), text: $name)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            Text(NSLocalizedString("name_native_hint", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Pronunciation guide
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("pronunciation_guide", comment: ""))
                                .font(.subheadline.weight(.semibold))
                            TextField(NSLocalizedString("pronunciation_guide_placeholder", comment: ""), text: $pronunciation)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(NSLocalizedString("add_language_variant", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("add", comment: "")) {
                        let variant = LanguageVariant(
                            language: selectedCode,
                            name: name.trimmingCharacters(in: .whitespaces),
                            pronunciation: pronunciation.trimmingCharacters(in: .whitespaces)
                        )
                        onAdd(variant)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if let first = availableLanguages.first {
                selectedCode = first.code
            }
        }
    }
}

