import Foundation

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let categoryID: UUID
    let categoryName: String
    let input: String
    let output: String
    let timestamp: Date

    init(categoryID: UUID, categoryName: String, input: String, output: String) {
        self.id = UUID()
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.input = input
        self.output = output
        self.timestamp = Date()
    }
}
