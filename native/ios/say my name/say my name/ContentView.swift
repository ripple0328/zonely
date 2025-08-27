import SwiftUI
import AVFoundation

struct NameEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var items: [LangItem]

    init(id: UUID = UUID(), displayName: String, items: [LangItem]) {
        self.id = id
        self.displayName = displayName
        self.items = items
    }
}

struct LangItem: Identifiable, Codable, Hashable {
    let id: UUID
    var bcp47: String
    var text: String

    init(id: UUID = UUID(), bcp47: String, text: String) {
        self.id = id
        self.bcp47 = bcp47
        self.text = text
    }
}

enum ProviderKind: Equatable {
    case human
    case tts
}

final class AppViewModel: ObservableObject {
    @Published var entries: [NameEntry] = []
    @Published var enText: String = ""
    @Published var zhText: String = ""
    @Published var enLang: String = "en-US"
    @Published var zhLang: String = "zh-CN"
    @Published var loadingPill: UUID?
    @Published var playingPill: UUID?
    @Published var providerKinds: [UUID: ProviderKind] = [:]

    private let network = PronounceService()
    private let audio = AudioCoordinator()
    private let persistence = StatePersistence()

    init() {
        entries = persistence.restore() ?? []
        audio.onFinish = { [weak self] in
            Task { @MainActor in
                self?.playingPill = nil
            }
        }
    }

    func addEntry() {
        guard !enText.trimmingCharacters(in: .whitespaces).isEmpty || !zhText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
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
                    try await audio.play(url: url)
                case .ttsAudio(let url):
                    providerKinds[item.id] = .tts
                    try await audio.play(url: url)
                case .sequence(let urls):
                    providerKinds[item.id] = .human
                    try await audio.playSequence(urls: urls)
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
}

struct ContentView: View {
    @EnvironmentObject private var vm: AppViewModel
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            // Glass background
            LinearGradient(colors: [Color.black.opacity(0.25), Color.blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    inputCard
                    list
                    footer
                }
                .padding(16)
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.ultraThickMaterial)
                .symbolRenderingMode(.hierarchical)
            Text("Say my name")
                .font(.headline)
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
    }

    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading) {
                    TextField("Name for English (e.g., San Zhang)", text: $vm.enText)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .en)
                        .onSubmit { focusedField = nil }
                    Picker("Language", selection: $vm.enLang) {
                        ForEach(LangCatalog.allCodes, id: \.self) { code in
                            Text(LangCatalog.displayName(code)).tag(code)
                        }
                    }.pickerStyle(.menu)
                }
                VStack(alignment: .leading) {
                    TextField("Name for native language (e.g., 张三)", text: $vm.zhText)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .zh)
                        .onSubmit { focusedField = nil }
                    Picker("Language", selection: $vm.zhLang) {
                        ForEach(LangCatalog.allCodes, id: \.self) { code in
                            Text(LangCatalog.displayName(code)).tag(code)
                        }
                    }.pickerStyle(.menu)
                }
            }
            Button(action: vm.addEntry) {
                Text("Add")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
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
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.10)))
            }
        }
    }

    private var footer: some View {
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
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
    }
}

private enum Field: Hashable { case en, zh }

struct LangPill: View {
    let item: LangItem
    let isLoading: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LangCatalog.displayName(item.bcp47))
                        .font(.caption)
                        .foregroundStyle(isPlaying ? .white.opacity(0.9) : .secondary)
                    Text(item.text.isEmpty ? "" : item.text)
                        .font(.callout)
                        .lineLimit(1)
                        .foregroundStyle(isPlaying ? .white : .primary)
                }
                if isLoading {
                    ProgressView().progressViewStyle(.circular)
                } else if isPlaying {
                    Image(systemName: vm.providerKinds[item.id] == .tts ? "sparkles" : "person.wave.2.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background {
            if isPlaying {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(
                    LinearGradient(colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isPlaying ? Color.white.opacity(0.35) : Color.white.opacity(0.15))
        )
        .shadow(color: (isPlaying ? Color.blue.opacity(0.25) : Color.black.opacity(0.08)), radius: 12, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AvatarView: View {
    let seed: String
    var body: some View {
        let normalized = seed
            .lowercased()
            .replacingOccurrences(of: "[^\\w\\s]+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
        let seedParam = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalized
        // Use PNG because AsyncImage/UIImage cannot render SVG by default
        let url = URL(string: "https://api.dicebear.com/7.x/avataaars/png?seed=\(seedParam)&backgroundColor=b6e3f4,c0aede,d1d4f9&size=64")
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack { Color.gray.opacity(0.2); ProgressView() }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.15)))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var runSpacing: CGFloat = 8

    init(spacing: CGFloat = 8, runSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.runSpacing = runSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                width = max(width, rowWidth)
                height += rowHeight + runSpacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }

        width = max(width, rowWidth)
        height += rowHeight
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + runSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

enum PronounceOutcome: Equatable {
    case audio(URL)
    case ttsAudio(URL)
    case sequence([URL])
    case tts(text: String, lang: String)
}

final class PronounceService {
    func pronounce(text: String, lang: String) async throws -> PronounceOutcome {
        let base = URL(string: currentBaseURL())!
        var url = base.appendingPathComponent("api/pronounce")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "name", value: text),
            URLQueryItem(name: "lang", value: lang)
        ]
        url = comps.url!

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let type = obj?["type"] as? String ?? ""
        switch type {
        case "audio":
            guard let s = obj?["url"] as? String, let u = resolveURL(s, base: base) else { throw URLError(.badServerResponse) }
            return .audio(u)
        case "tts_audio":
            guard let s = obj?["url"] as? String, let u = resolveURL(s, base: base) else { throw URLError(.badServerResponse) }
            return .ttsAudio(u)
        case "sequence":
            guard let arr = obj?["urls"] as? [String] else { throw URLError(.badServerResponse) }
            return .sequence(arr.compactMap { resolveURL($0, base: base) })
        case "tts":
            let text = obj?["text"] as? String ?? text
            let lang = obj?["lang"] as? String ?? lang
            return .tts(text: text, lang: lang)
        default:
            throw URLError(.badServerResponse)
        }
    }

    private func resolveURL(_ s: String, base: URL) -> URL? {
        if let u = URL(string: s), u.scheme != nil {
            return u
        }
        return URL(string: s, relativeTo: base)?.absoluteURL
    }

    private func currentBaseURL() -> String {
        // Heuristics similar to web: supports /name path when running under that path
        // For device builds, point to production hostname; override for local testing as needed.
        #if DEBUG
        return "http://studio:4000" // adjust if using device
        #else
        return "https://name.qingbo.us"
        #endif
    }
}

final class AudioCoordinator: NSObject {
    private let cache = AudioCache()
    private var player: AVAudioPlayer?
    var onFinish: (() -> Void)?
    private var remainingInSequence: Int = 0
    private let synth = AVSpeechSynthesizer()

    override init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // ignore session errors
        }
        super.init()
        synth.delegate = self
    }

    func play(url: URL) async throws {
        let local = try await cache.file(for: url)
        guard isSupported(url: local) else { throw URLError(.cannotDecodeContentData) }
        try playLocal(url: local)
    }

    func playSequence(urls: [URL]) async throws {
        remainingInSequence = urls.count
        for u in urls {
            try await play(url: u)
            // wait for completion of each item
            while let p = player, p.isPlaying { try await Task.sleep(nanoseconds: 50_000_000) }
        }
    }

    func speak(text: String, bcp47: String) async throws {
        let utter = AVSpeechUtterance(string: text)
        utter.voice = AVSpeechSynthesisVoice(language: bcp47)
        synth.speak(utter)
    }

    private func playLocal(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        player?.delegate = self
        player?.play()
    }

    private func isSupported(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supported = ["mp3","m4a","aac","caf","aif","aiff","wav","mp4"]
        return supported.contains(ext)
    }
}

extension AudioCoordinator: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if remainingInSequence > 0 {
            remainingInSequence -= 1
            if remainingInSequence == 0 { onFinish?() }
        } else {
            onFinish?()
        }
    }
}

extension AudioCoordinator: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}

final class AudioCache {
    private let fm = FileManager.default

    func file(for remote: URL) async throws -> URL {
        let cacheDir = try cacheDirectory()
        let name = cacheKey(for: remote)
        let local = cacheDir.appendingPathComponent(name)
        if fm.fileExists(atPath: local.path) {
            return local
        }
        let (data, _) = try await URLSession.shared.data(from: remote)
        try data.write(to: local, options: .atomic)
        return local
    }

    private func cacheDirectory() throws -> URL {
        let base = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("SayMyNameCache", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func cacheKey(for url: URL) -> String {
        let s = url.absoluteString
        return s.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "-")
    }
}

enum LangCatalog {
    static let allCodes: [String] = [
        "en-US","es-ES","fr-FR","de-DE","pt-BR","zh-CN","ja-JP","hi-IN","bn-IN","ta-IN","te-IN","mr-IN","gu-IN","kn-IN","ml-IN","pa-IN","ar-SA"
    ]
    static func displayName(_ code: String) -> String {
        [
            "en-US":"English","zh-CN":"中文","ja-JP":"日本語","es-ES":"Español","fr-FR":"Français","de-DE":"Deutsch","pt-BR":"Português","hi-IN":"हिन्दी","ar-SA":"العربية","bn-IN":"বাংলা","ta-IN":"தமிழ்","te-IN":"తెలుగు","mr-IN":"मराठी","gu-IN":"ગુજરાતી","kn-IN":"ಕನ್ನಡ","ml-IN":"മലയാളം","pa-IN":"ਪੰਜਾਬੀ"
        ][code] ?? code
    }
}

final class StatePersistence {
    private let key = "names_state_v1"
    func restore() -> [NameEntry]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([NameEntry].self, from: data)
    }
    func store(_ entries: [NameEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum DeepLinkBuilder {
    static func url(for entries: [NameEntry]) -> URL {
        let payload: [[String: Any]] = entries.map { entry in
            [
                "name": entry.displayName,
                "entries": entry.items.map { ["lang": $0.bcp47, "text": $0.text] }
            ]
        }
        let data = try? JSONSerialization.data(withJSONObject: payload)
        let base64 = (data?.base64EncodedString() ?? "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        #if DEBUG
        let base = "http://localhost:4000"
        #else
        let base = "https://name.qingbo.us"
        #endif
        var comps = URLComponents(string: base)!
        comps.queryItems = [URLQueryItem(name: "s", value: base64)]
        return comps.url ?? URL(string: base)!
    }
}


