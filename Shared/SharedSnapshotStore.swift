import Foundation

enum SharedSnapshotStore {
    private static var snapshotURL: URL {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroup
        ) {
            try? FileManager.default.createDirectory(
                at: container,
                withIntermediateDirectories: true
            )
            return container.appendingPathComponent(AppConstants.snapshotFilename)
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BiliDesk", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback.appendingPathComponent(AppConstants.snapshotFilename)
    }

    static func load() -> ContentSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder.biliDecoder.decode(ContentSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: ContentSnapshot) throws {
        let data = try JSONEncoder.biliEncoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }
}

extension JSONDecoder {
    static var biliDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var biliEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
