import SwiftUI

struct AvatarView: View {
    let seed: String
    var body: some View {
        let normalized = seed
            .lowercased()
            .replacingOccurrences(of: "[^\\w\\s]+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
        let seedParam = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalized
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


