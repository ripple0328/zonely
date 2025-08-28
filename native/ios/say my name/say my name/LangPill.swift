import SwiftUI

struct LangPill: View {
    let item: LangItem
    let isLoading: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        Button(action: {
            Haptics.shared.impact(.soft)
            onTap()
        }) {
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
        .shadow(color: (isPlaying ? Color.blue.opacity(0.35) : Color.black.opacity(0.08)), radius: isPlaying ? 16 : 12, x: 0, y: isPlaying ? 8 : 6)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .scaleEffect(isPlaying ? 1.02 : 1.0)
        .animation(isPlaying ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: isPlaying)
    }
}


