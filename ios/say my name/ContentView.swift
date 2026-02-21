import SwiftUI
import AVFoundation
import UIKit

// Types moved to Models.swift: NameEntry, LangItem, ProviderKind

final class AppViewModel: ObservableObject {
    @Published var entries: [NameEntry] = []
    @Published var collections: [NameCollection] = []
    @Published var activeCollectionId: UUID = UUID()
    // Simplified input: single name + language picker
    @Published var nameText: String = ""
    @Published var selectedLang: String = "en-US"
    @Published var pronOverrideText: String = ""
    @Published var showPronOverride: Bool = false
    @Published var scriptMismatch: Bool = false
    @Published var loadingPill: UUID?
    @Published var playingPill: UUID?
    @Published var providerKinds: [UUID: ProviderKind] = [:]
    @Published var ttsCacheCount: Int = 0
    @Published var shareUrl: URL?
    // Undo-on-remove
    @Published var removedEntry: NameEntry?
    @Published var removedIndex: Int?
    @Published var showUndoToast: Bool = false
    private var undoTimer: Timer?

    var activeCollection: NameCollection? {
        collections.first(where: { $0.id == activeCollectionId })
    }

    private var network: PronounceNetworking
    private var audio: AudioPlaying
    private let ttsCache = AudioCacheManager()
    private let persistence = StatePersistence()
    private let collectionPersistence = CollectionPersistence()

    init(network: PronounceNetworking = PronounceService(), audio: AudioPlaying = AudioCoordinator(cache: AudioCacheManager())) {
        self.network = network
        self.audio = audio

        // Restore collections; migrate legacy entries if needed
        var restored = collectionPersistence.restore() ?? []
        if restored.isEmpty {
            let legacyEntries = persistence.restore() ?? []
            let defaultCol = NameCollection(name: "My Names", entries: legacyEntries)
            restored = [defaultCol]
            collectionPersistence.store(restored)
        }
        collections = restored

        // Restore active collection ID; default to first
        if let savedId = collectionPersistence.restoreActiveId(),
           collections.contains(where: { $0.id == savedId }) {
            activeCollectionId = savedId
        } else {
            activeCollectionId = collections[0].id
        }
        collectionPersistence.storeActiveId(activeCollectionId)

        // Load entries from active collection
        entries = activeCollection?.entries ?? []

        ttsCacheCount = ttsCache.count()
        audio.onFinish = { [weak self] in
            Task { @MainActor in
                self?.playingPill = nil
                self?.loadingPill = nil
            }
        }
    }

    func addEntry() {
        let name = nameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        recomputeMismatches()
        guard !scriptMismatch else { return }
        // Use override text if provided, otherwise use the name
        let pronText = showPronOverride && !pronOverrideText.trimmingCharacters(in: .whitespaces).isEmpty
            ? pronOverrideText.trimmingCharacters(in: .whitespaces)
            : name
        // Check override text also matches the language
        if showPronOverride && !pronOverrideText.trimmingCharacters(in: .whitespaces).isEmpty {
            guard LanguageHeuristics.matches(text: pronText, bcp47: selectedLang) else {
                scriptMismatch = true
                return
            }
        }
        let item = LangItem(bcp47: selectedLang, text: pronText)
        entries.append(NameEntry(displayName: name, items: [item]))
        resetInputForm()
        save()
    }

    func resetInputForm() {
        nameText = ""
        pronOverrideText = ""
        showPronOverride = false
        scriptMismatch = false
        selectedLang = "en-US"
    }

    func removeEntry(_ entry: NameEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        // Cancel any existing undo timer
        undoTimer?.invalidate()
        // If there was a pending removal, finalize it
        finalizeRemoval()
        removedEntry = entry
        removedIndex = idx
        entries.remove(at: idx)
        showUndoToast = true
        save()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finalizeRemoval()
            }
        }
    }

    func undoRemoval() {
        undoTimer?.invalidate()
        guard let entry = removedEntry, let idx = removedIndex else { return }
        let insertIdx = min(idx, entries.count)
        entries.insert(entry, at: insertIdx)
        removedEntry = nil
        removedIndex = nil
        showUndoToast = false
        save()
    }

    func finalizeRemoval() {
        removedEntry = nil
        removedIndex = nil
        showUndoToast = false
    }

    func addPronunciation(to entryId: UUID, lang: String, text: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        let item = LangItem(bcp47: lang, text: text)
        entries[idx].items.append(item)
        save()
    }

    func play(_ item: LangItem, displayName: String) {
        loadingPill = item.id
        playingPill = nil
        Task { @MainActor in
            do {
                let outcome = try await network.pronounce(text: item.text.isEmpty ? displayName : item.text, lang: item.bcp47)
                switch outcome {
                case .audio(let url):
                    providerKinds[item.id] = .human
                    playingPill = item.id
                    loadingPill = nil
                    try await audio.play(url: url, lang: item.bcp47)
                case .ttsAudio(let url):
                    providerKinds[item.id] = .tts
                    playingPill = item.id
                    loadingPill = nil
                    try await audio.play(url: url, lang: item.bcp47)
                    ttsCacheCount = ttsCache.count()
                case .sequence(let urls):
                    providerKinds[item.id] = .human
                    playingPill = item.id
                    loadingPill = nil
                    try await audio.playSequence(urls: urls, lang: item.bcp47)
                case .tts(let text, let lang):
                    providerKinds[item.id] = .tts
                    playingPill = item.id
                    loadingPill = nil
                    try await audio.speak(text: text, bcp47: lang)
                }
            } catch {
                // Fallback to TTS if audio playback fails (e.g. unsupported format like .ogg)
                let fallbackText = item.text.isEmpty ? displayName : item.text
                providerKinds[item.id] = .tts
                playingPill = item.id
                loadingPill = nil
                try? await audio.speak(text: fallbackText, bcp47: item.bcp47)
            }
            loadingPill = nil
        }
    }

    func save() {
        // Auto-save entries into the active collection
        if let idx = collections.firstIndex(where: { $0.id == activeCollectionId }) {
            collections[idx].entries = entries
        }
        collectionPersistence.store(collections)
        collectionPersistence.storeActiveId(activeCollectionId)
        // Keep legacy persistence for backward compat
        persistence.store(entries)
    }

    // MARK: - Collection Management (inline, matching web UX)

    func switchCollection(to id: UUID) {
        guard id != activeCollectionId else { return }
        // Save current entries to active collection before switching
        save()
        activeCollectionId = id
        collectionPersistence.storeActiveId(id)
        entries = activeCollection?.entries ?? []
    }

    func createCollection(name: String) {
        save() // persist current entries first
        let col = NameCollection(name: name, entries: [])
        collections.append(col)
        activeCollectionId = col.id
        entries = []
        save()
    }

    func renameCollection(id: UUID, name: String) {
        guard let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].name = name
        collectionPersistence.store(collections)
    }

    func duplicateCollection(id: UUID) {
        guard let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        save() // persist current entries first
        let source = collections[idx]
        let dup = NameCollection(name: source.name + " (copy)", entries: source.entries)
        collections.insert(dup, at: idx + 1)
        activeCollectionId = dup.id
        entries = dup.entries
        save()
    }

    func deleteCollection(id: UUID) {
        guard collections.count > 1 else { return }
        guard let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections.remove(at: idx)
        if activeCollectionId == id {
            let newIdx = max(0, idx - 1)
            activeCollectionId = collections[newIdx].id
            entries = collections[newIdx].entries
        }
        save()
    }

    func importFromSharedUrl(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let sParam = components.queryItems?.first(where: { $0.name == "s" })?.value else {
            showDeepLinkError()
            return
        }

        guard let newEntries = CollectionShareUrl.decode(sParam) else {
            showDeepLinkError()
            return
        }

        // Use cn param for collection name if present, otherwise fallback
        let collectionName = components.queryItems?.first(where: { $0.name == "cn" })?.value
        let col = NameCollection(
            name: collectionName ?? "Imported - \(Date().formatted(date: .abbreviated, time: .omitted))",
            entries: newEntries
        )
        save() // persist current entries first
        collections.append(col)
        activeCollectionId = col.id
        entries = newEntries
        save()
    }

    func clearTtsCache() {
        ttsCache.clear()
        ttsCacheCount = 0
    }
    
    func recomputeMismatches() {
        let name = nameText.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            scriptMismatch = false
            return
        }
        let nameMatches = LanguageHeuristics.matches(text: name, bcp47: selectedLang)
        if !nameMatches {
            scriptMismatch = true
            // Auto-show the pronunciation override field when there's a script mismatch
            showPronOverride = true
            return
        }
        // If override is shown and has text, check that too
        if showPronOverride && !pronOverrideText.trimmingCharacters(in: .whitespaces).isEmpty {
            scriptMismatch = !LanguageHeuristics.matches(text: pronOverrideText, bcp47: selectedLang)
        } else {
            scriptMismatch = false
        }
    }
    
    func loadFromDeepLink(url: URL) {
        // Handle both custom scheme (saymyname://) and https://saymyname.qingbo.us
        let isValidScheme = url.scheme == "saymyname" || url.host == AppConfig.websiteDomain
        guard isValidScheme else { return }

        // Enforce a conservative size limit to avoid excessive payloads
        if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "s" })?.value,
           query.count > 4096 {
            showDeepLinkError()
            return
        }

        importFromSharedUrl(url)
    }

    private func showDeepLinkError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        print("Invalid or too-large deep link data")
    }
}

struct ContentView: View {
    @EnvironmentObject private var vm: AppViewModel
    @FocusState private var focusedField: Field?
    // Rename collection alert state
    @State private var showRenameAlert = false
    @State private var renameCollectionId: UUID?
    @State private var renameText = ""
    // New collection inline input
    @State private var showNewCollectionInput = false
    @State private var newCollectionName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                LinearGradient(colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        collectionsBar
                        inputCard
                        list
                        footer
                        analyticsCard
                        footerLinks
                    }
                    .padding(16)
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
                .onChange(of: focusedField) { _ in
                    vm.recomputeMismatches()
                }
                // Undo toast overlay
                if vm.showUndoToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Text(NSLocalizedString("undo_remove", comment: "Undo remove toast"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                vm.undoRemoval()
                                Haptics.shared.impact(.light)
                            } label: {
                                Text(NSLocalizedString("undo", comment: "Undo button"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: vm.showUndoToast)
                }
            }
            .alert(NSLocalizedString("rename_collection", comment: "Rename collection alert title"), isPresented: $showRenameAlert) {
                TextField(NSLocalizedString("collection_name_placeholder", comment: ""), text: $renameText)
                Button(NSLocalizedString("save", comment: "Save")) {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if let id = renameCollectionId, !trimmed.isEmpty {
                        vm.renameCollection(id: id, name: trimmed)
                    }
                }
                Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {}
            }
        }
    }

    // MARK: - Collections Bar (horizontal scroll pills matching web)
    private var collectionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.collections) { col in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.switchCollection(to: col.id)
                        }
                        Haptics.shared.impact(.light)
                    } label: {
                        Text(col.name)
                            .font(.subheadline.weight(col.id == vm.activeCollectionId ? .semibold : .regular))
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                col.id == vm.activeCollectionId
                                    ? AnyShapeStyle(Color.accentColor)
                                    : AnyShapeStyle(.ultraThinMaterial)
                            , in: Capsule())
                            .foregroundStyle(col.id == vm.activeCollectionId ? .white : .primary)
                            .overlay(
                                Capsule().strokeBorder(
                                    col.id == vm.activeCollectionId
                                        ? Color.clear
                                        : Color.white.opacity(0.22),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(col.name)
                    .accessibilityAddTraits(col.id == vm.activeCollectionId ? .isSelected : [])
                    .contextMenu {
                        Button {
                            renameCollectionId = col.id
                            renameText = col.name
                            showRenameAlert = true
                        } label: {
                            Label(NSLocalizedString("rename", comment: "Rename"), systemImage: "pencil")
                        }

                        Button {
                            vm.duplicateCollection(id: col.id)
                            Haptics.shared.impact(.medium)
                        } label: {
                            Label(NSLocalizedString("duplicate", comment: "Duplicate"), systemImage: "doc.on.doc")
                        }

                        if vm.collections.count > 1 {
                            Button(role: .destructive) {
                                vm.deleteCollection(id: col.id)
                                Haptics.shared.notification(.warning)
                            } label: {
                                Label(NSLocalizedString("delete", comment: "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }

                // + New button (or inline input)
                if showNewCollectionInput {
                    HStack(spacing: 4) {
                        TextField(NSLocalizedString("collection_name_placeholder", comment: ""), text: $newCollectionName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .submitLabel(.done)
                            .onSubmit { commitNewCollection() }
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 120)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNewCollectionInput = true
                            newCollectionName = ""
                        }
                    } label: {
                        Text("+ " + NSLocalizedString("new", comment: "New"))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(.secondary)
                    }
                    .background(
                        Capsule()
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
                    .accessibilityLabel(NSLocalizedString("create_new_collection", comment: "Create new collection"))
                }
            }
            .padding(.vertical, 4)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.activeCollectionId)
        .animation(.easeInOut(duration: 0.2), value: showNewCollectionInput)
    }

    private func commitNewCollection() {
        let trimmed = newCollectionName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            vm.createCollection(name: trimmed)
            Haptics.shared.impact(.medium)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            showNewCollectionInput = false
            newCollectionName = ""
        }
    }

    // Simplified input: name + language picker + optional override
    private var inputCard: some View {
        VStack(spacing: 12) {
            // Row: Name input + Language picker + Add button
            HStack(spacing: 8) {
                TextField(NSLocalizedString("name_placeholder", comment: "Name placeholder"), text: $vm.nameText)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = nil
                        if canAdd { vm.addEntry(); Haptics.shared.impact(.medium) }
                    }
                    .onChange(of: vm.nameText) { _ in vm.recomputeMismatches() }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(vm.scriptMismatch ? Color.orange.opacity(0.9) : Color.white.opacity(0.22)))
                    .overlay(alignment: .trailing) {
                        if vm.scriptMismatch {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .imageScale(.small)
                                .padding(.trailing, 8)
                        }
                    }

                Menu {
                    ForEach(LangCatalog.allCodes, id: \.self) { code in
                        Button(action: { vm.selectedLang = code; vm.recomputeMismatches() }) {
                            HStack {
                                Text(LangCatalog.displayName(code))
                                if code == vm.selectedLang {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(LangCatalog.displayName(vm.selectedLang))
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.22)))
                }
                .accessibilityLabel(NSLocalizedString("language", comment: "Language label"))

                Button(action: {
                    if vm.scriptMismatch {
                        Haptics.shared.notification(.warning)
                    } else {
                        Haptics.shared.impact(.medium)
                        vm.addEntry()
                    }
                }) {
                    Text(NSLocalizedString("add", comment: "Add button"))
                        .bold()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }

            // Script mismatch warning
            if vm.scriptMismatch {
                Text(String(format: NSLocalizedString("text_may_not_match_lang", comment: "mismatch warning"), LangCatalog.displayName(vm.selectedLang)))
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Pronunciation override field (shown on mismatch or by toggle)
            if vm.showPronOverride {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("pronunciation_text_label", comment: "Pronunciation text label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(NSLocalizedString("pronunciation_text_placeholder", comment: "Pronunciation text placeholder"), text: $vm.pronOverrideText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .pronOverride)
                        .onSubmit {
                            focusedField = nil
                            if canAdd { vm.addEntry(); Haptics.shared.impact(.medium) }
                        }
                        .onChange(of: vm.pronOverrideText) { _ in vm.recomputeMismatches() }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.22)))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Toggle for pronunciation override
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.showPronOverride.toggle()
                    if !vm.showPronOverride {
                        vm.pronOverrideText = ""
                        vm.recomputeMismatches()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .imageScale(.small)
                    Text(NSLocalizedString("customize_pronunciation", comment: "Customize pronunciation toggle"))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(NSLocalizedString("customize_pronunciation", comment: ""))
            .accessibilityAddTraits(vm.showPronOverride ? .isSelected : [])
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.14))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.05))
                    .blur(radius: 1)
            }
        )
        .animation(.easeInOut(duration: 0.2), value: vm.showPronOverride)
        .animation(.easeInOut(duration: 0.2), value: vm.scriptMismatch)
    }

    private var canAdd: Bool {
        !vm.nameText.trimmingCharacters(in: .whitespaces).isEmpty && !vm.scriptMismatch
    }

    @State private var addPronEntryId: UUID?
    @State private var addPronLang: String = "en-US"
    @State private var addPronText: String = ""

    private var list: some View {
        VStack(spacing: 10) {
            if vm.entries.isEmpty {
                Text(NSLocalizedString("empty_list_message", comment: "Empty state message"))
                    .foregroundStyle(.secondary)
                    .padding()
            }
            ForEach(vm.entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        AvatarView(seed: entry.displayName)
                        Text(entry.displayName).font(.headline)
                        Spacer()
                        // Add pronunciation button
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if addPronEntryId == entry.id {
                                    addPronEntryId = nil
                                } else {
                                    addPronEntryId = entry.id
                                    // Default to a language not already on the card
                                    let usedLangs = Set(entry.items.map(\.bcp47))
                                    addPronLang = LangCatalog.allCodes.first(where: { !usedLangs.contains($0) }) ?? "en-US"
                                    addPronText = ""
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(NSLocalizedString("add_pronunciation", comment: "Add pronunciation"))

                        Button(role: .destructive) { vm.removeEntry(entry) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.bordered)
                    }
                    // Language pills
                    if entry.items.count <= 2 {
                        HStack(spacing: 12) {
                            ForEach(entry.items) { item in
                                LangPill(item: item, displayName: entry.displayName, isLoading: vm.loadingPill == item.id, isPlaying: vm.playingPill == item.id) {
                                    vm.play(item, displayName: entry.displayName)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if entry.items.count == 1 {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 0)
                            }
                        }
                    } else {
                        FlowLayout(spacing: 8, runSpacing: 8) {
                            ForEach(entry.items) { item in
                                LangPill(item: item, displayName: entry.displayName, isLoading: vm.loadingPill == item.id, isPlaying: vm.playingPill == item.id) {
                                    vm.play(item, displayName: entry.displayName)
                                }
                            }
                        }
                    }

                    // Inline add-pronunciation form
                    if addPronEntryId == entry.id {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                TextField(NSLocalizedString("pronunciation_text_placeholder", comment: ""), text: $addPronText)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.22)))

                                Menu {
                                    ForEach(LangCatalog.allCodes, id: \.self) { code in
                                        Button(LangCatalog.displayName(code)) { addPronLang = code }
                                    }
                                } label: {
                                    Text(LangCatalog.displayName(addPronLang))
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.22)))
                                }
                            }
                            HStack(spacing: 8) {
                                Button(NSLocalizedString("add", comment: "")) {
                                    let text = addPronText.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? entry.displayName
                                        : addPronText.trimmingCharacters(in: .whitespaces)
                                    vm.addPronunciation(to: entry.id, lang: addPronLang, text: text)
                                    Haptics.shared.impact(.medium)
                                    withAnimation { addPronEntryId = nil }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button(NSLocalizedString("cancel", comment: "")) {
                                    withAnimation { addPronEntryId = nil }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Spacer()
                            }
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.04))
                            .blur(radius: 1)
                    }
                )
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            // Share section
            HStack {
                Text(NSLocalizedString("share_your_list", comment: "Share header"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                ShareLink(item: DeepLinkBuilder.url(for: vm.entries, collectionName: vm.activeCollection?.name)) {
                    Label(NSLocalizedString("share", comment: "Share button"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            // Cache row removed per design
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.04))
                    .blur(radius: 1)
            }
        )
    }

    private var analyticsCard: some View {
        NavigationLink {
            PublicAnalyticsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Community Stats")
                        .font(.headline)
                    Text("See top names, languages & global usage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
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
        .buttonStyle(.plain)
    }

    private var footerLinks: some View {
        HStack(spacing: 12) {
            NavigationLink("Privacy") {
                PrivacyView()
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            Text("·").font(.caption2).foregroundStyle(.tertiary)
            NavigationLink("About") {
                AboutView()
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
    }
}

private enum Field: Hashable { case name, pronOverride }



