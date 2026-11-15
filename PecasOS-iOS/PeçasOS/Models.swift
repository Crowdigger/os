import Foundation

struct PieceRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var orderNumber: String
    var client: String
    var storageLocation: String
    var photoNames: [String]
    var executionSheetName: String?
    var createdAt: Date = Date()
}
