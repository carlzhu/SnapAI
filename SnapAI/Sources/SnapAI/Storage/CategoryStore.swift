import Foundation

@MainActor
final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()
    @Published var categories: [Category] = []
    private let storageKey = "custom_categories"

    private init() { load() }

    func addCategory(_ category: Category) {
        categories.append(category)
        save()
    }

    func removeCategory(id: UUID) {
        categories.removeAll { $0.id == id && !$0.isBuiltin }
        save()
    }

    private func load() {
        var all = Category.builtins
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let custom = try? JSONDecoder().decode([Category].self, from: data) {
            all.append(contentsOf: custom)
        }
        categories = all
    }

    private func save() {
        let custom = categories.filter { !$0.isBuiltin }
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
