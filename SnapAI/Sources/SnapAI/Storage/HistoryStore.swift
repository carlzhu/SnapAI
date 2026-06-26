import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    @Published var items: [HistoryItem] = []
    private let storageKey = "ai_history"
    private let maxItems = 100

    private init() { load() }

    func addItem(_ item: HistoryItem) {
        items.insert(item, at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        save()
    }

    func clearAll() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        self.items = items
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
