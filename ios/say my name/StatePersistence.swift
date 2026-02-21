import Foundation

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


