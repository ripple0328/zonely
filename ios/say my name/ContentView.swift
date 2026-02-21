import SwiftUI
import AVFoundation
import UIKit

// Types moved to Models.swift: NameEntry, LangItem, ProviderKind

final class AppViewModel: ObservableObject {
    @Published var entries: [NameEntry] = []
    @Published var collections: [NameCollection] = []
    @Published var currentCollection: NameCollection?
    @Published var commonText: String = ""
    @Published var originalText: String = ""
    @Published var commonLang: String = "en-US"
    @Published var originalLang: String = "zh-CN"
    @Published var loadingPill: UUID?
    @Published var playingPill: UUID?
    @Published var providerKinds: [UUID: ProviderKind] = [:]
    @Published var commonMismatch: Bool = false
    @Published var originalMismatch: Bool = false
    @Published var ttsCacheCount: Int = 0
    @Published var shareUrl: URL?


    private var network: PronounceNetworking
    private var audio: AudioPlaying
    private let ttsCache = AudioCacheManager()
    private let persistence = StatePersistence()
    private let collectionPersistence = CollectionPersistence()

    init(network: PronounceNetworking = PronounceService(), audio: AudioPlaying = AudioCoordinator(cache: AudioCacheManager())) {
        self.network = network
        self.audio = audio
        entries = persistence.restore() ?? []
        collections = collectionPersistence.restore() ?? []
        ttsCacheCount = ttsCache.count()
        audio.onFinish = { [weak self] in
            Task { @MainActor in
                self?.playingPill = nil
                self?.loadingPill = nil
            }
        }
    }

    func addEntry() {
        guard !commonText.trimmingCharacters(in: .whitespaces).isEmpty || !originalText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        commonMismatch = !LanguageHeuristics.matches(text: commonText, bcp47: commonLang)
        originalMismatch = !LanguageHeuristics.matches(text: originalText, bcp47: originalLang)
        // Prevent adding when mismatched
        guard !(commonMismatch || originalMismatch) else { return }
        var items: [LangItem] = []
        if !commonText.isEmpty { items.append(LangItem(bcp47: commonLang, text: commonText)) }
        if !originalText.isEmpty { items.append(LangItem(bcp47: originalLang, text: originalText)) }
        let display = originalText.isEmpty ? commonText : originalText
        entries.append(NameEntry(displayName: display, items: items))
        commonText = ""
        originalText = ""
        save()
    }

    func removeEntry(_ entry: NameEntry) {
        entries.removeAll { $0.id == entry.id }
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
        persistence.store(entries)
    }

    // MARK: - Collection Management
    func createCollection(name: String, description: String? = nil) {
        let collection = NameCollection(
            name: name,
            description: description,
            entries: entries
        )
        collectionPersistence.add(collection, to: &collections)
    }

    func updateCollection(_ collection: NameCollection) {
        var updated = collection
        updated.entries = entries
        collectionPersistence.update(updated, in: &collections)
    }

    func deleteCollection(_ collection: NameCollection) {
        collectionPersistence.delete(collection, from: &collections)
        if currentCollection?.id == collection.id {
            currentCollection = nil
        }
    }

    func loadCollection(_ collection: NameCollection) {
        entries = collection.entries
        currentCollection = collection
        save()
    }

    func shareCollection(_ collection: NameCollection) {
        shareUrl = CollectionShareUrl.generateUrl(for: collection.entries)
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

        // Create a new collection from the shared data
        let collection = NameCollection(
            name: "Imported - \(Date().formatted(date: .abbreviated, time: .omitted))",
            entries: newEntries
        )
        collectionPersistence.add(collection, to: &collections)
        entries = newEntries
        save()
    }

    func clearTtsCache() {
        ttsCache.clear()
        ttsCacheCount = 0
    }
    
    func recomputeMismatches() {
        commonMismatch = !LanguageHeuristics.matches(text: commonText, bcp47: commonLang)
        originalMismatch = !LanguageHeuristics.matches(text: originalText, bcp47: originalLang)
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
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Tab
            NavigationStack {
                ZStack {
                    // Glass background
                    LinearGradient(colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 16) {
                            inputCard
                            list
                            footer
                            analyticsCard
                            // Privacy/About links at the bottom
                            footerLinks
                        }
                        .padding(16)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = nil }
                    .onChange(of: focusedField) { _ in
                        vm.recomputeMismatches()
                    }
                }
            }
            .tabItem {
                Label("Names", systemImage: "list.bullet")
            }
            .tag(0)

            // Collections Tab
            CollectionsView()
                .tabItem {
                    Label("Collections", systemImage: "folder")
                }
                .tag(1)
        }
    }

    // header removed to maximize content space
    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField(NSLocalizedString("common_spelling_placeholder", comment: "Common spelling placeholder"), text: $vm.commonText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .en)
                        .onSubmit { focusedField = nil }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(vm.commonMismatch ? Color.orange.opacity(0.9) : Color.white.opacity(0.22)))
                        .overlay(alignment: .trailing) {
                            if vm.commonMismatch {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .imageScale(.small)
                                    .padding(.trailing, 8)
                            }
                        }
                    Text(String(format: NSLocalizedString("text_may_not_match_lang", comment: "mismatch warning"), LangCatalog.displayName(vm.commonLang)))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .frame(height: 12)
                        .opacity(vm.commonMismatch ? 1 : 0)
                    Menu {
                        ForEach(LangCatalog.allCodes, id: \.self) { code in
                            Button(action: { vm.commonLang = code; vm.recomputeMismatches() }) {
                                Text(LangCatalog.displayName(code))
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(LangCatalog.displayName(vm.commonLang))
                            Image(systemName: "chevron.down")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .accessibilityLabel(NSLocalizedString("language", comment: "Language label"))
                    
                }
                VStack(alignment: .leading, spacing: 6) {
                    TextField(NSLocalizedString("original_spelling_placeholder", comment: "Original spelling placeholder"), text: $vm.originalText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .zh)
                        .onSubmit { focusedField = nil }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(vm.originalMismatch ? Color.orange.opacity(0.9) : Color.white.opacity(0.22)))
                        .overlay(alignment: .trailing) {
                            if vm.originalMismatch {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .imageScale(.small)
                                    .padding(.trailing, 8)
                            }
                        }
                    Text(String(format: NSLocalizedString("text_may_not_match_lang", comment: "mismatch warning"), LangCatalog.displayName(vm.originalLang)))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .frame(height: 12)
                        .opacity(vm.originalMismatch ? 1 : 0)
                    Menu {
                        ForEach(LangCatalog.allCodes, id: \.self) { code in
                            Button(action: { vm.originalLang = code; vm.recomputeMismatches() }) {
                                Text(LangCatalog.displayName(code))
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(LangCatalog.displayName(vm.originalLang))
                            Image(systemName: "chevron.down")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .accessibilityLabel(NSLocalizedString("language", comment: "Language label"))
                    
                }
            }
            Button(action: {
                if vm.commonMismatch || vm.originalMismatch {
                    Haptics.shared.notification(.warning)
                } else {
                    Haptics.shared.impact(.medium)
                    vm.addEntry()
                }
            }) {
                Text(NSLocalizedString("add", comment: "Add button"))
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .disabled(vm.commonMismatch || vm.originalMismatch)
            .buttonStyle(.borderedProminent)
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
    }

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
                        Button(role: .destructive) { vm.removeEntry(entry) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.bordered)
                    }
                    // If only two languages, align as two equal-width pills for better balance
                    if entry.items.count <= 2 {
                        HStack(spacing: 12) {
                            ForEach(entry.items) { item in
                                LangPill(item: item, isLoading: vm.loadingPill == item.id, isPlaying: vm.playingPill == item.id) {
                                    vm.play(item, displayName: entry.displayName)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            // If only one pill, keep symmetry with an invisible spacer pill
                            if entry.items.count == 1 {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 0)
                            }
                        }
                    } else {
                        FlowLayout(spacing: 8, runSpacing: 8) {
                            ForEach(entry.items) { item in
                                LangPill(item: item, isLoading: vm.loadingPill == item.id, isPlaying: vm.playingPill == item.id) {
                                    vm.play(item, displayName: entry.displayName)
                                }
                            }
                        }
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
                ShareLink(item: DeepLinkBuilder.url(for: vm.entries)) {
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

private enum Field: Hashable { case en, zh }



