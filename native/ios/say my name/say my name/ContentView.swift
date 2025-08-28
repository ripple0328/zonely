import SwiftUI
import AVFoundation
import UIKit

// Types moved to Models.swift: NameEntry, LangItem, ProviderKind

final class AppViewModel: ObservableObject {
    @Published var entries: [NameEntry] = []
    @Published var enText: String = ""
    @Published var zhText: String = ""
    @Published var enLang: String = "en-US"
    @Published var zhLang: String = "zh-CN"
    @Published var loadingPill: UUID?
    @Published var playingPill: UUID?
    @Published var providerKinds: [UUID: ProviderKind] = [:]
    @Published var englishMismatch: Bool = false
    @Published var nativeMismatch: Bool = false


    private var network: PronounceNetworking
    private var audio: AudioPlaying
    private let persistence = StatePersistence()

    init(network: PronounceNetworking = PronounceService(), audio: AudioPlaying = AudioCoordinator()) {
        self.network = network
        self.audio = audio
        entries = persistence.restore() ?? []
        audio.onFinish = { [weak self] in
            Task { @MainActor in
                self?.playingPill = nil
            }
        }
    }

    func addEntry() {
        guard !enText.trimmingCharacters(in: .whitespaces).isEmpty || !zhText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        englishMismatch = !LanguageHeuristics.matches(text: enText, bcp47: enLang)
        nativeMismatch = !LanguageHeuristics.matches(text: zhText, bcp47: zhLang)
        // Prevent adding when mismatched
        guard !(englishMismatch || nativeMismatch) else { return }
        var items: [LangItem] = []
        if !enText.isEmpty { items.append(LangItem(bcp47: enLang, text: enText)) }
        if !zhText.isEmpty { items.append(LangItem(bcp47: zhLang, text: zhText)) }
        let display = zhText.isEmpty ? enText : zhText
        entries.append(NameEntry(displayName: display, items: items))
        enText = ""
        zhText = ""
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
                    try await audio.play(url: url, lang: item.bcp47)
                case .ttsAudio(let url):
                    providerKinds[item.id] = .tts
                    try await audio.play(url: url, lang: item.bcp47)
                case .sequence(let urls):
                    providerKinds[item.id] = .human
                    try await audio.playSequence(urls: urls, lang: item.bcp47)
                case .tts(let text, let lang):
                    providerKinds[item.id] = .tts
                    try await audio.speak(text: text, bcp47: lang)
                }
                playingPill = item.id
            } catch {
                // Fallback to TTS if audio playback fails (e.g. unsupported format like .ogg)
                let fallbackText = item.text.isEmpty ? displayName : item.text
                providerKinds[item.id] = .tts
                try? await audio.speak(text: fallbackText, bcp47: item.bcp47)
                playingPill = item.id
            }
            loadingPill = nil
        }
    }

    func save() {
        persistence.store(entries)
    }
    
    func recomputeMismatches() {
        englishMismatch = !LanguageHeuristics.matches(text: enText, bcp47: enLang)
        nativeMismatch = !LanguageHeuristics.matches(text: zhText, bcp47: zhLang)
    }
    
    func loadFromDeepLink(url: URL) {
        // Handle both custom scheme (saymyname://) and https://saymyname.qingbo.us
        let queryItems: [URLQueryItem]?
        
        if url.scheme == "saymyname" {
            // Custom scheme: saymyname://?s=...
            queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        } else if url.host == AppConfig.websiteDomain {
            // HTTPS: https://saymyname.qingbo.us/?s=...
            queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        } else {
            return
        }
        
        guard let items = queryItems,
              let sParam = items.first(where: { $0.name == "s" })?.value else {
            return
        }
        
        // Decode Base64 URL-safe encoding
        let base64 = sParam
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let paddedBase64 = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        
        guard let data = Data(base64Encoded: paddedBase64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        
        // Parse the shared data structure
        var newEntries: [NameEntry] = []
        for item in json {
            guard let name = item["name"] as? String,
                  let entriesArray = item["entries"] as? [[String: String]] else {
                continue
            }
            
            var langItems: [LangItem] = []
            for entry in entriesArray {
                guard let lang = entry["lang"], let text = entry["text"] else { continue }
                langItems.append(LangItem(bcp47: lang, text: text))
            }
            
            if !langItems.isEmpty {
                newEntries.append(NameEntry(displayName: name, items: langItems))
            }
        }
        
        // Replace current entries with shared ones
        if !newEntries.isEmpty {
            entries = newEntries
            save()
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var vm: AppViewModel
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            // Glass background
            LinearGradient(colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    inputCard
                    list
                    footer
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

    // header removed to maximize content space
    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading) {
                    TextField("English Name", text: $vm.enText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .en)
                        .onSubmit { focusedField = nil }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(vm.englishMismatch ? Color.orange.opacity(0.9) : Color.white.opacity(0.22)))
                        .overlay(alignment: .trailing) {
                            if vm.englishMismatch {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .imageScale(.small)
                                    .padding(.trailing, 8)
                            }
                        }
                    Text("Text may not match \(LangCatalog.displayName(vm.enLang))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .frame(height: 14)
                        .opacity(vm.englishMismatch ? 1 : 0)
                    Picker("Language", selection: $vm.enLang) {
                        ForEach(LangCatalog.allCodes, id: \.self) { code in
                            Text(LangCatalog.displayName(code)).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vm.enLang) { _ in vm.recomputeMismatches() }
                    
                }
                VStack(alignment: .leading) {
                    TextField("Native Name", text: $vm.zhText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .zh)
                        .onSubmit { focusedField = nil }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(vm.nativeMismatch ? Color.orange.opacity(0.9) : Color.white.opacity(0.22)))
                        .overlay(alignment: .trailing) {
                            if vm.nativeMismatch {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .imageScale(.small)
                                    .padding(.trailing, 8)
                            }
                        }
                    Text("Text may not match \(LangCatalog.displayName(vm.zhLang))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .frame(height: 14)
                        .opacity(vm.nativeMismatch ? 1 : 0)
                    Picker("Language", selection: $vm.zhLang) {
                        ForEach(LangCatalog.allCodes, id: \.self) { code in
                            Text(LangCatalog.displayName(code)).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vm.zhLang) { _ in vm.recomputeMismatches() }
                    
                }
            }
            Button(action: {
                if vm.englishMismatch || vm.nativeMismatch {
                    Haptics.shared.notification(.warning)
                } else {
                    Haptics.shared.impact(.medium)
                    vm.addEntry()
                }
            }) {
                Text("Add")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .disabled(vm.englishMismatch || vm.nativeMismatch)
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
                Text("No names yet. Add a name and language to begin.")
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
                Text("Share your list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                ShareLink(item: DeepLinkBuilder.url(for: vm.entries)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }

            // Cache management with clear action pinned to bottom feel
            CacheManagementView()
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
}

private enum Field: Hashable { case en, zh }

// moved to LangPill.swift

// moved to AvatarView.swift

// moved to FlowLayout.swift

// Networking moved to PronounceService.swift

// AudioCoordinator moved to AudioCoordinator.swift


// moved to LangCatalog.swift

// moved to StatePersistence.swift

// moved to DeepLinkBuilder.swift

struct CacheManagementView: View {
    @ObservedObject private var cacheManager = AudioCacheManager.shared
    @State private var showingClearAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            let cacheInfo = cacheManager.getCacheInfo()
            Text("\(cacheInfo.count) pronunciations cached")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            if cacheInfo.count > 0 {
                Button {
                    Haptics.shared.impact(.light)
                    showingClearAlert = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .alert("Clear Audio Cache", isPresented: $showingClearAlert) {
            Button("Clear", role: .destructive) {
                cacheManager.clearAllCache()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all cached audio files. They will be downloaded again when needed.")
        }
    }
}

struct CacheSummaryView: View {
    @ObservedObject private var cacheManager = AudioCacheManager.shared
    var body: some View {
        // trigger updates when statsVersion changes
        let _ = cacheManager.statsVersion
        let info = cacheManager.getCacheInfo()
        return HStack {
            Text("\(info.count) pronunciations cached")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            if info.count > 0 {
                Text(cacheManager.formattedCacheSize())
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// moved to Haptics.swift


