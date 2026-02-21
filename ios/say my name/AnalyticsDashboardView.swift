import SwiftUI
import Combine

@MainActor
final class AnalyticsDashboardViewModel: ObservableObject {
    @Published var dashboard: AnalyticsDashboard?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedRange = "24h"
    @Published var lastUpdatedAt: Date?
    @Published var connectionState: ChannelConnectionState = .disconnected
    @Published var showUpdatePulse = false
    @Published var highlightedCards: Set<String> = []

    private let service = AnalyticsDashboardService()
    private let channelService = AnalyticsChannelService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupChannelSubscription()
    }

    private func setupChannelSubscription() {
        // Observe connection state
        channelService.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        // Observe analytics events
        channelService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleAnalyticsEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleAnalyticsEvent(_ event: AnalyticsEvent) {
        // Trigger pulse animation
        withAnimation(.easeInOut(duration: 0.3)) {
            showUpdatePulse = true
        }

        // Highlight all metric cards briefly
        let cards = ["totalPlays", "cacheHitRate", "errorRate", "conversion"]
        highlightedCards = Set(cards)

        // Reset animations after delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.showUpdatePulse = false
                }
            }
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.5)) {
                    self.highlightedCards.removeAll()
                }
            }
        }

        // Refresh dashboard data
        Task {
            await load()
        }
    }

    func load() async {
        isLoading = dashboard == nil // Only show loading on first load
        error = nil
        do {
            dashboard = try await service.fetchDashboard(range: selectedRange)
            lastUpdatedAt = Date()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func connectChannel() {
        channelService.connect()
    }

    func disconnectChannel() {
        channelService.disconnect()
    }
}

struct AnalyticsDashboardView: View {
    @StateObject private var vm = AnalyticsDashboardViewModel()

    private let ranges = ["24h", "7d", "30d"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    timeRangePicker

                    if vm.isLoading {
                        loadingView
                    } else if let error = vm.error {
                        errorView(error)
                    } else if let dashboard = vm.dashboard {
                        metricsGrid(dashboard)
                        topNamesSection(dashboard.topNames)
                        topLanguagesSection(dashboard.topLanguages)
                        geoDistributionSection(dashboard.geoDistribution)
                    }
                }
                .padding(16)
            }

            .refreshable { await vm.load() }
        }
        .task {
            await vm.load()
            vm.connectChannel()
        }
        .onDisappear {
            vm.disconnectChannel()
        }
        .onChange(of: vm.selectedRange) { _ in Task { await vm.load() } }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(.indigo)
            Text("Analytics Dashboard")
                .font(.title2.bold())

            Spacer()

            // Live indicator with connection status
            liveIndicator
        }
        .overlay(
            // Pulse effect on update
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(vm.showUpdatePulse ? 0.8 : 0), lineWidth: 2)
                .scaleEffect(vm.showUpdatePulse ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.5), value: vm.showUpdatePulse)
        )
    }

    // MARK: - Live Indicator
    private var liveIndicator: some View {
        HStack(spacing: 6) {
            // Animated dot
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(connectionColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(vm.connectionState == .connected ? 1.5 : 1.0)
                        .opacity(vm.connectionState == .connected ? 0 : 1)
                        .animation(
                            vm.connectionState == .connected
                                ? .easeOut(duration: 1.0).repeatForever(autoreverses: false)
                                : .default,
                            value: vm.connectionState
                        )
                )

            Text(connectionText)
                .font(.caption.bold())
                .foregroundStyle(connectionColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(connectionColor.opacity(0.15), in: Capsule())
    }

    private var connectionColor: Color {
        switch vm.connectionState {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected: return .gray
        }
    }

    private var connectionText: String {
        switch vm.connectionState {
        case .connected: return "Live"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "Offline"
        }
    }

    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        VStack(spacing: 8) {
            Picker("Time Range", selection: $vm.selectedRange) {
                ForEach(ranges, id: \.self) { range in
                    Text(range).tag(range)
                }
            }
            .pickerStyle(.segmented)

            // Last updated timestamp
            if let lastUpdated = vm.lastUpdatedAt {
                TimeAgoView(date: lastUpdated)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(glassOverlay(radius: 16))
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading analytics...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(glassOverlay(radius: 20))
    }

    // MARK: - Error View
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Failed to load analytics")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(glassOverlay(radius: 20))
    }

    // MARK: - Metrics Grid
    private func metricsGrid(_ dashboard: AnalyticsDashboard) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(
                id: "totalPlays",
                title: "Total Plays",
                value: "\(dashboard.totalPronunciations)",
                icon: "play.circle.fill",
                color: .indigo
            )
            metricCard(
                id: "cacheHitRate",
                title: "Cache Hit Rate",
                value: String(format: "%.1f%%", dashboard.cacheHitRate),
                icon: "bolt.fill",
                color: .green
            )
            metricCard(
                id: "errorRate",
                title: "Error Rate",
                value: String(format: "%.1f%%", dashboard.errorStats.errorRate),
                icon: "exclamationmark.circle.fill",
                color: .orange
            )
            metricCard(
                id: "conversion",
                title: "Conversion",
                value: String(format: "%.1f%%", dashboard.conversion.conversionRate),
                icon: "arrow.right.circle.fill",
                color: .blue
            )
        }
    }

    private func metricCard(id: String, title: String, value: String, icon: String, color: Color) -> some View {
        let isHighlighted = vm.highlightedCards.contains(id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
                Spacer()
            }
            Text(value)
                .font(.title.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.08), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(color.opacity(isHighlighted ? 0.8 : 0), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(color.opacity(isHighlighted ? 0.15 : 0))
        )
        .overlay(glassOverlay(radius: 20))
        .shadow(color: color.opacity(0.06), radius: 8, y: 4)
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
    }

    // MARK: - Provider Performance Section
    private func providerPerformanceSection(_ providers: [ProviderPerformance]) -> some View {
        sectionCard(title: "Provider Performance", icon: "server.rack") {
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                HStack(spacing: 12) {
                    rankBadge(index + 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.provider)
                            .font(.subheadline.bold())
                        if let avg = provider.avgGenerationTimeMs {
                            Text("Avg: \(avg)ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(provider.totalRequests)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.indigo)
                }
                .padding(.vertical, 4)
                if index < providers.count - 1 {
                    Divider().opacity(0.3)
                }
            }
        }
    }

    // MARK: - Top Names Section
    private func topNamesSection(_ names: [TopName]) -> some View {
        sectionCard(title: "Top Names", icon: "person.fill") {
            ForEach(Array(names.prefix(10).enumerated()), id: \.element.id) { index, name in
                HStack(spacing: 12) {
                    rankBadge(index + 1)
                    langPill(for: name.lang)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.name)
                            .font(.subheadline.bold())
                        Text(LangCatalog.displayName(name.lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(name.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.indigo)
                }
                .padding(.vertical, 4)
                if index < min(names.count, 10) - 1 {
                    Divider().opacity(0.3)
                }
            }
        }
    }

    // MARK: - Top Languages Section
    private func topLanguagesSection(_ languages: [TopLanguage]) -> some View {
        sectionCard(title: "Top Languages", icon: "globe") {
            ForEach(Array(languages.prefix(10).enumerated()), id: \.element.id) { index, language in
                HStack(spacing: 12) {
                    rankBadge(index + 1)
                    langPill(for: language.lang)
                    Text(LangCatalog.displayName(language.lang))
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(language.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.indigo)
                }
                .padding(.vertical, 4)
                if index < min(languages.count, 10) - 1 {
                    Divider().opacity(0.3)
                }
            }
        }
    }

    // MARK: - Geographic Distribution Section
    private func geoDistributionSection(_ geoData: [GeoDistribution]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.indigo)
                Text("Geographic Distribution")
                    .font(.headline)
                Spacer()
                if !geoData.isEmpty {
                    Text("\(geoData.count) countries")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if geoData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                    Text("No geographic data yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                GeoHeatmapView(geoDistribution: geoData)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(glassOverlay(radius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Reusable Components
    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.indigo)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(glassOverlay(radius: 20))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    private func rankBadge(_ rank: Int) -> some View {
        let color: Color = {
            switch rank {
            case 1: return .yellow
            case 2: return Color(white: 0.65)
            case 3: return .orange
            default: return .indigo.opacity(0.4)
            }
        }()
        return Text("\(rank)")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color.gradient, in: Circle())
            .shadow(color: color.opacity(0.3), radius: 3, y: 1)
    }

    /// Returns the script character for a language code
    private func langScriptChar(for langCode: String) -> String {
        let base = langCode.split(separator: "-").first.map(String.init) ?? langCode
        switch base {
        case "en": return "Aa"
        case "zh": return "中"
        case "ja": return "あ"
        case "es": return "Eñ"
        case "fr": return "Ça"
        case "de": return "Ää"
        case "pt": return "Ão"
        case "hi": return "हि"
        case "ar": return "عر"
        case "bn": return "বা"
        case "ko": return "한"
        case "ru": return "Яа"
        case "it": return "Àa"
        case "tr": return "Öö"
        case "vi": return "Đđ"
        case "th": return "ไท"
        case "pl": return "Łł"
        case "nl": return "Aa"
        case "sv": return "Åä"
        default: return "Aa"
        }
    }

    /// Returns the solid color for a language code
    private func langColor(for langCode: String) -> Color {
        let base = langCode.split(separator: "-").first.map(String.init) ?? langCode
        switch base {
        case "en": return Color(red: 0.38, green: 0.56, blue: 0.85)  // soft blue
        case "es": return Color(red: 0.90, green: 0.48, blue: 0.40)  // warm coral
        case "zh": return Color(red: 0.85, green: 0.35, blue: 0.35)  // soft red
        case "ja": return Color(red: 0.82, green: 0.45, blue: 0.65)  // soft pink
        case "hi": return Color(red: 0.40, green: 0.72, blue: 0.55)  // sage green
        case "ar": return Color(red: 0.82, green: 0.65, blue: 0.38)  // warm sand
        case "fr": return Color(red: 0.55, green: 0.50, blue: 0.82)  // lavender
        case "ko": return Color(red: 0.65, green: 0.42, blue: 0.78)  // soft purple
        case "de": return Color(red: 0.45, green: 0.55, blue: 0.68)  // slate blue
        case "pt": return Color(red: 0.35, green: 0.70, blue: 0.65)  // soft teal
        case "bn": return Color(red: 0.45, green: 0.75, blue: 0.68)  // mint
        case "ru": return Color(red: 0.75, green: 0.45, blue: 0.50)  // dusty rose
        case "it": return Color(red: 0.38, green: 0.68, blue: 0.48)  // muted emerald
        case "tr": return Color(red: 0.80, green: 0.52, blue: 0.38)  // terracotta
        case "vi": return Color(red: 0.58, green: 0.68, blue: 0.38)  // olive/moss
        case "th": return Color(red: 0.62, green: 0.40, blue: 0.65)  // plum
        case "pl": return Color(red: 0.42, green: 0.58, blue: 0.82)  // cornflower
        case "nl": return Color(red: 0.85, green: 0.60, blue: 0.35)  // muted orange
        case "sv": return Color(red: 0.78, green: 0.68, blue: 0.35)  // honey gold
        default:   return Color(red: 0.60, green: 0.60, blue: 0.62)  // neutral gray
        }
    }

    private func langPill(for langCode: String) -> some View {
        Text(langScriptChar(for: langCode))
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(langColor(for: langCode), in: Circle())
    }

    private func glassOverlay(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.18), .white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Time Ago View
struct TimeAgoView: View {
    let date: Date
    @State private var timeAgo: String = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
            Text("Updated \(timeAgo)")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .onAppear { updateTimeAgo() }
        .onReceive(timer) { _ in updateTimeAgo() }
    }

    private func updateTimeAgo() {
        let interval = Date().timeIntervalSince(date)
        if interval < 5 {
            timeAgo = "just now"
        } else if interval < 60 {
            timeAgo = "\(Int(interval))s ago"
        } else if interval < 3600 {
            timeAgo = "\(Int(interval / 60))m ago"
        } else {
            timeAgo = "\(Int(interval / 3600))h ago"
        }
    }
}

#Preview {
    AnalyticsDashboardView()
}
