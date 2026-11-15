import Foundation
import UIKit

@MainActor
final class PieceStore: ObservableObject {
    @Published private(set) var records: [PieceRecord] = []
    @Published var lastError: String?

    private let folder: URL
    private let photosFolder: URL
    private let databaseFile: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PecasOS", isDirectory: true)
        folder = base
        photosFolder = base.appendingPathComponent("Fotos", isDirectory: true)
        databaseFile = base.appendingPathComponent("registros.json")
        do {
            try FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: databaseFile.path) {
                let data = try Data(contentsOf: databaseFile)
                records = try JSONDecoder().decode([PieceRecord].self, from: data)
            }
        } catch {
            lastError = "Não foi possível carregar os cadastros: \(error.localizedDescription)"
        }
    }

    func photoURL(_ name: String) -> URL { photosFolder.appendingPathComponent(name) }

    func image(_ name: String?) -> UIImage? {
        guard let name, let data = try? Data(contentsOf: photoURL(name)) else { return nil }
        return UIImage(data: data)
    }

    /// Preserve detail in photographed paperwork while avoiding camera-original sizes.
    func savePhoto(_ original: UIImage, isExecutionSheet: Bool) throws -> String {
        let maxDimension: CGFloat = isExecutionSheet ? 2400 : 1920
        let jpegQuality: CGFloat = isExecutionSheet ? 0.88 : 0.85
        let normalized = normalizedImage(original, maximum: maxDimension)
        guard let data = normalized.jpegData(compressionQuality: jpegQuality) else {
            throw StorageError.cannotEncode
        }
        let name = UUID().uuidString + ".jpg"
        try data.write(to: photoURL(name), options: .atomic)
        return name
    }

    private func normalizedImage(_ image: UIImage, maximum: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maximum ? maximum / longestSide : 1
        let target = CGSize(width: max(1, (image.size.width * scale).rounded()),
                            height: max(1, (image.size.height * scale).rounded()))
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    func save(_ record: PieceRecord) throws {
        var updated = records
        if let index = updated.firstIndex(where: { $0.id == record.id }) { updated[index] = record }
        else { updated.insert(record, at: 0) }
        try persist(updated)
        let old = records.first(where: { $0.id == record.id })
        records = updated
        if let old { cleanupPhotos(from: old) }
    }

    func duplicate(_ record: PieceRecord) throws {
        var copied = PieceRecord(orderNumber: record.orderNumber, client: record.client,
                                 storageLocation: record.storageLocation, photoNames: [],
                                 executionSheetName: nil, createdAt: Date())
        var created: [String] = []
        do {
            for name in record.photoNames {
                let newName = UUID().uuidString + ".jpg"
                try FileManager.default.copyItem(at: photoURL(name), to: photoURL(newName))
                created.append(newName)
                copied.photoNames.append(newName)
            }
            if let sheet = record.executionSheetName {
                let newName = UUID().uuidString + ".jpg"
                try FileManager.default.copyItem(at: photoURL(sheet), to: photoURL(newName))
                created.append(newName)
                copied.executionSheetName = newName
            }
            try save(copied)
        } catch {
            created.forEach { try? FileManager.default.removeItem(at: photoURL($0)) }
            throw error
        }
    }

    func delete(_ record: PieceRecord) throws {
        let updated = records.filter { $0.id != record.id }
        try persist(updated)
        records = updated
        cleanupPhotos(from: record)
    }

    /// Only delete images no longer referenced by any record.
    private func cleanupPhotos(from old: PieceRecord) {
        let referenced = Set(records.flatMap(\.photoNames) + records.compactMap(\.executionSheetName))
        for name in old.photoNames + [old.executionSheetName].compactMap({ $0 }) where !referenced.contains(name) {
            try? FileManager.default.removeItem(at: photoURL(name))
        }
    }

    func removeUnreferenced(_ names: [String]) {
        let referenced = Set(records.flatMap(\.photoNames) + records.compactMap(\.executionSheetName))
        for name in names where !referenced.contains(name) {
            try? FileManager.default.removeItem(at: photoURL(name))
        }
    }

    private func persist(_ records: [PieceRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: databaseFile, options: .atomic)
    }

    private struct BackupEntry: Codable {
        let ordem: String
        let local: String
        let cliente: String
        let criado: Int64
        let fotos: [String]
        let ficha: String?
    }
    private struct BackupManifest: Codable {
        let format: String
        let version: Int
        let exportedAt: Int64
        let records: [BackupEntry]
    }

    /// No network calls: the user chooses iCloud Drive or On My iPhone in Files.
    func makeBackup() throws -> Data {
        var images: [(String, Data)] = []
        var archiveNames: [String: String] = [:]
        func imagePath(_ name: String) throws -> String {
            if let existing = archiveNames[name] { return existing }
            let data = try Data(contentsOf: photoURL(name))
            guard !data.isEmpty else { throw BackupFailure.missingImage }
            let backupName = "photos/\(UUID().uuidString).jpg"
            archiveNames[name] = backupName
            images.append((backupName, data))
            return backupName
        }
        var entries: [BackupEntry] = []
        for record in records {
            let photos = try record.photoNames.map { try imagePath($0) }
            let sheet = try record.executionSheetName.map { try imagePath($0) }
            entries.append(BackupEntry(ordem: record.orderNumber, local: record.storageLocation,
                                       cliente: record.client,
                                       criado: Int64(record.createdAt.timeIntervalSince1970 * 1000),
                                       fotos: photos, ficha: sheet))
        }
        let manifest = BackupManifest(format: "pecasos-backup", version: 1,
                                      exportedAt: Int64(Date().timeIntervalSince1970 * 1000), records: entries)
        let manifestData = try JSONEncoder().encode(manifest)
        return try BackupZip.encode([("manifest.json", manifestData)] + images)
    }

    /// Validates the archive before replacing any registration. Existing records remain
    /// untouched if decoding or copying photos fails.
    func restoreBackup(_ data: Data) throws -> Int {
        let files = try BackupZip.decode(data)
        guard let json = files["manifest.json"] else { throw BackupFailure.invalidManifest }
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: json)
        guard manifest.format == "pecasos-backup", manifest.version == 1,
              manifest.records.count <= 10_000 else { throw BackupFailure.invalidManifest }
        var newRecords: [PieceRecord] = []
        var references: [String: String] = [:]
        var pending: [(String, Data)] = []
        func renamedPhoto(_ archiveName: String) throws -> String {
            if let existing = references[archiveName] { return existing }
            guard archiveName.hasPrefix("photos/"),
                  let photo = files[archiveName], !photo.isEmpty,
                  UIImage(data: photo) != nil else { throw BackupFailure.missingImage }
            let newName = UUID().uuidString + ".jpg"
            references[archiveName] = newName
            pending.append((newName, photo))
            return newName
        }
        for entry in manifest.records {
            guard !entry.ordem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !entry.local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1...5).contains(entry.fotos.count), entry.criado > 0 else {
                throw BackupFailure.invalidManifest
            }
            let photoNames = try entry.fotos.map { try renamedPhoto($0) }
            let sheetName = try entry.ficha.map { try renamedPhoto($0) }
            newRecords.append(PieceRecord(orderNumber: entry.ordem, client: entry.cliente,
                                          storageLocation: entry.local, photoNames: photoNames,
                                          executionSheetName: sheetName,
                                          createdAt: Date(timeIntervalSince1970: Double(entry.criado)/1000)))
        }
        var created: [URL] = []
        do {
            for (name, photo) in pending {
                let url = photoURL(name)
                try photo.write(to: url, options: .atomic)
                created.append(url)
            }
            try persist(newRecords)
        } catch {
            created.forEach { try? FileManager.default.removeItem(at: $0) }
            throw error
        }
        let previous = records
        records = newRecords
        for old in previous { cleanupPhotos(from: old) }
        return newRecords.count
    }

    enum BackupFailure: LocalizedError {
        case missingImage, invalidManifest
        var errorDescription: String? {
            switch self {
            case .missingImage: return "O backup contém uma foto ausente ou danificada."
            case .invalidManifest: return "O backup não possui dados válidos do Peças OS."
            }
        }
    }

    enum StorageError: LocalizedError {
        case cannotEncode
        var errorDescription: String? { "Não foi possível processar esta fotografia." }
    }
}
