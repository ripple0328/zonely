import SwiftUI
import Combine

@MainActor
final class PublicAnalyticsViewModel: ObservableObject {
    @Published var dashboard: AnalyticsDashboard?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedRange = "24h"
    @Published var lastUpdatedAt: Date?
    @Published var connectionState: ChannelConnectionState = .disconnected
    @Published var showUpdatePulse = false
    @Published var hasAppeared = false

    private let service = AnalyticsDashboardService()
    private let channelService = AnalyticsChannelService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupChannelSubscription()
    }

    private func setupChannelSubscription() {
        channelService.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        channelService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAnalyticsEvent()
            }
            .store(in: &cancellables)
    }

    private func handleAnalyticsEvent() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showUpdatePulse = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) {
                    self.showUpdatePulse = false
                }
            }
        }
        Task { await load() }
    }

    func load() async {
        isLoading = dashboard == nil
        error = nil
        do {
            dashboard = try await service.fetchDashboard(range: selectedRange)
            lastUpdatedAt = Date()
            if !hasAppeared {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func connectChannel() { channelService.connect() }
    func disconnectChannel() { channelService.disconnect() }
}

struct PublicAnalyticsView: View {
    @StateObject private var vm = PublicAnalyticsViewModel()

    private let ranges = ["24h", "7d", "30d"]

    var body: some View {
        ZStack {
            // Light glass background matching app theme
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    timeRangePicker

                    if vm.isLoading {
                        loadingView
                    } else if let error = vm.error {
                        errorView(error)
                    } else if let dashboard = vm.dashboard {
                        totalPlaysCard(dashboard)
                            .staggerIn(index: 0, appeared: vm.hasAppeared)

                        topNamesSection(dashboard.topNames)
                            .staggerIn(index: 1, appeared: vm.hasAppeared)

                        topLanguagesSection(dashboard.topLanguages)
                            .staggerIn(index: 2, appeared: vm.hasAppeared)

                        geoDistributionSection(dashboard.geoDistribution)
                            .staggerIn(index: 3, appeared: vm.hasAppeared)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable { await vm.load() }
        }
        .task {
            await vm.load()
            vm.connectChannel()
        }
        .onDisappear { vm.disconnectChannel() }
        .onChange(of: vm.selectedRange) { _ in Task { await vm.load() } }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.title2)
                .foregroundStyle(.indigo)
                .symbolRenderingMode(.hierarchical)
            Text("Analytics")
                .font(.title2.weight(.semibold))
            Spacer()
            liveIndicator
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Live Indicator
    private var liveIndicator: some View {
        HStack(spacing: 6) {
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

            if let lastUpdated = vm.lastUpdatedAt {
                TimeAgoView(date: lastUpdated)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.14)))
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(glassOverlay(radius: 18))
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(glassOverlay(radius: 18))
    }

    // MARK: - Total Plays Card
    private func totalPlaysCard(_ dashboard: AnalyticsDashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.indigo)
                Text("Total Plays")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                // Sparkle on live update
                if vm.showUpdatePulse {
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Text("\(dashboard.totalPronunciations)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dashboard.totalPronunciations)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                // Subtle gradient accent along the top
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.15), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay(glassOverlay(radius: 20))
        .shadow(color: .indigo.opacity(0.08), radius: 12, y: 6)
    }

    // MARK: - Top Names Section
    private func topNamesSection(_ names: [TopName]) -> some View {
        sectionCard(title: "Top Requested Names", icon: "person.2.fill") {
            ForEach(Array(names.prefix(10).enumerated()), id: \.element.id) { index, name in
                HStack(spacing: 12) {
                    rankBadge(index + 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name.name)
                            .font(.subheadline.weight(.semibold))
                        Text(name.lang)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    Spacer()
                    Text("\(name.count)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.indigo)
                }
                .padding(.vertical, 5)
                if index < min(names.count, 10) - 1 {
                    Divider().opacity(0.15)
                }
            }
        }
    }

    // MARK: - Top Languages Section
    private func topLanguagesSection(_ languages: [TopLanguage]) -> some View {
        let maxCount = languages.first?.count ?? 1
        return sectionCard(title: "Top Languages", icon: "globe.americas.fill") {
            ForEach(Array(languages.prefix(8).enumerated()), id: \.element.id) { index, language in
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        rankBadge(index + 1)
                        Text(LangCatalog.displayName(language.lang))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(language.count)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.indigo)
                    }
                    // Proportion bar
                    GeometryReader { geo in
                        let fraction = CGFloat(language.count) / CGFloat(max(maxCount, 1))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.indigo.opacity(0.6), .indigo.opacity(0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * fraction, height: 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)
                    }
                    .frame(height: 4)
                }
                .padding(.vertical, 3)
                if index < min(languages.count, 8) - 1 {
                    Divider().opacity(0.1)
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

    private func glassOverlay(radius: CGFloat) -> some View {
        ZStack {
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
}

// MARK: - Stagger Animation Modifier
private struct StaggerModifier: ViewModifier {
    let index: Int
    let appeared: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.78)
                    .delay(Double(index) * 0.08),
                value: appeared
            )
    }
}

extension View {
    func staggerIn(index: Int, appeared: Bool) -> some View {
        modifier(StaggerModifier(index: index, appeared: appeared))
    }
}

#Preview {
    PublicAnalyticsView()
}
