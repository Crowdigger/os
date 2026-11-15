import Foundation

/// Portable ZIP with STORED entries (JPEG files are already compressed).
/// Compatible with the Android Peças OS manual backup format.
enum BackupZip {
    enum ArchiveError: LocalizedError {
        case malformed, tooLarge, unsupported
        var errorDescription: String? {
            switch self {
            case .malformed: return "O arquivo de backup é inválido ou está danificado."
            case .tooLarge: return "Este backup é grande demais para ser processado neste aparelho."
            case .unsupported: return "Este backup usa um tipo de compactação ainda não compatível."
            }
        }
    }

    private struct Entry { let name: String; let contents: Data; let crc: UInt32; let localOffset: UInt32 }
    private static let maxArchiveSize = 512 * 1024 * 1024

    static func encode(_ files: [(String, Data)]) throws -> Data {
        var bytes = Data()
        var directory: [Entry] = []
        guard files.count <= 20_000 else { throw ArchiveError.tooLarge }
        var names = Set<String>()
        for (name, content) in files {
            guard validName(name), names.insert(name).inserted else { throw ArchiveError.malformed }
            let utf8 = Array(name.utf8)
            guard utf8.count <= 65_535 && content.count < Int(UInt32.max) && bytes.count < maxArchiveSize else { throw ArchiveError.tooLarge }
            let crc = checksum(content)
            let offset = UInt32(bytes.count)
            bytes.add32(0x04034b50) // local header
            bytes.add16(20); bytes.add16(0x0800); bytes.add16(0) // ZIP version, UTF-8, stored
            bytes.add16(0); bytes.add16(0) // DOS time/date
            bytes.add32(crc); bytes.add32(UInt32(content.count)); bytes.add32(UInt32(content.count))
            bytes.add16(UInt16(utf8.count)); bytes.add16(0)
            bytes.append(contentsOf: utf8); bytes.append(content)
            directory.append(Entry(name: name, contents: content, crc: crc, localOffset: offset))
        }
        let centralOffset = UInt32(bytes.count)
        for entry in directory {
            let utf8 = Array(entry.name.utf8)
            bytes.add32(0x02014b50); bytes.add16(20); bytes.add16(20)
            bytes.add16(0x0800); bytes.add16(0); bytes.add16(0); bytes.add16(0)
            bytes.add32(entry.crc)
            bytes.add32(UInt32(entry.contents.count)); bytes.add32(UInt32(entry.contents.count))
            bytes.add16(UInt16(utf8.count)); bytes.add16(0); bytes.add16(0)
            bytes.add16(0); bytes.add16(0); bytes.add32(0); bytes.add32(entry.localOffset)
            bytes.append(contentsOf: utf8)
        }
        let centralSize = UInt32(bytes.count) - centralOffset
        guard directory.count <= 65_535 && bytes.count + 22 <= maxArchiveSize else { throw ArchiveError.tooLarge }
        bytes.add32(0x06054b50); bytes.add16(0); bytes.add16(0)
        bytes.add16(UInt16(directory.count)); bytes.add16(UInt16(directory.count))
        bytes.add32(centralSize); bytes.add32(centralOffset); bytes.add16(0)
        return bytes
    }

    static func decode(_ data: Data) throws -> [String: Data] {
        guard data.count >= 22 && data.count <= maxArchiveSize else { throw ArchiveError.malformed }
        var result: [String: Data] = [:]
        var position = 0
        while position + 4 <= data.count {
            let signature = try data.read32(position)
            if signature == 0x02014b50 || signature == 0x06054b50 { break }
            guard signature == 0x04034b50, position + 30 <= data.count else { throw ArchiveError.malformed }
            let flags = try data.read16(position + 6)
            let method = try data.read16(position + 8)
            guard method == 0 && (flags & 0x0008) == 0 else { throw ArchiveError.unsupported }
            let crc = try data.read32(position + 14)
            let packed = Int(try data.read32(position + 18))
            let unpacked = Int(try data.read32(position + 22))
            let nameLength = Int(try data.read16(position + 26))
            let extraLength = Int(try data.read16(position + 28))
            let start = position + 30 + nameLength + extraLength
            guard packed == unpacked, packed <= 60 * 1024 * 1024,
                  nameLength > 0, start <= data.count, packed <= data.count - start else { throw ArchiveError.malformed }
            let nameData = data.subdata(in: (position+30)..<(position+30+nameLength))
            guard let name = String(data: nameData, encoding: .utf8), validName(name), result[name] == nil else {
                throw ArchiveError.malformed
            }
            let contents = data.subdata(in: start..<(start + packed))
            guard checksum(contents) == crc else { throw ArchiveError.malformed }
            result[name] = contents
            guard result.count <= 20_000 else { throw ArchiveError.tooLarge }
            position = start + packed
        }
        guard result["manifest.json"] != nil else { throw ArchiveError.malformed }
        return result
    }

    private static func validName(_ name: String) -> Bool {
        if name == "manifest.json" { return true }
        return name.range(of: #"^photos/[A-Za-z0-9_-]+\.jpg$"#, options: .regularExpression) != nil
    }
    private static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xedb8_8320 : 0) }
        }
        return ~crc
    }
}

private extension Data {
    mutating func add16(_ number: UInt16) {
        append(UInt8(truncatingIfNeeded: number)); append(UInt8(truncatingIfNeeded: number >> 8))
    }
    mutating func add32(_ number: UInt32) {
        add16(UInt16(truncatingIfNeeded: number)); add16(UInt16(truncatingIfNeeded: number >> 16))
    }
    func read16(_ offset: Int) throws -> UInt16 {
        guard offset >= 0 && offset + 2 <= count else { throw BackupZip.ArchiveError.malformed }
        return UInt16(self[self.index(startIndex, offsetBy: offset)])
             | (UInt16(self[self.index(startIndex, offsetBy: offset + 1)]) << 8)
    }
    func read32(_ offset: Int) throws -> UInt32 {
        return UInt32(try read16(offset)) | (UInt32(try read16(offset + 2)) << 16)
    }
}
