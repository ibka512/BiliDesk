import Foundation

struct VideoItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let ownerName: String
    let coverURL: URL?
    let duration: Int
    let viewCount: Int?
    let progress: Int?
    let viewedAt: Date?

    var webURL: URL {
        URL(string: "https://www.bilibili.com/video/\(id)")!
    }

    var durationText: String {
        guard duration > 0 else { return "" }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    var viewCountText: String? {
        guard let viewCount else { return nil }
        if viewCount >= 100_000_000 { return String(format: "%.1f亿", Double(viewCount) / 100_000_000) }
        if viewCount >= 10_000 { return String(format: "%.1f万", Double(viewCount) / 10_000) }
        return "\(viewCount)"
    }
}

struct AccountSummary: Codable, Hashable, Sendable {
    let mid: Int64
    let name: String
    let avatarURL: URL?
}

struct ContentSnapshot: Codable, Sendable {
    var recommendations: [VideoItem]
    var history: [VideoItem]
    var favorites: [VideoItem]
    var watchLater: [VideoItem]
    var account: AccountSummary?
    var updatedAt: Date
    var lastError: String?

    static let empty = ContentSnapshot(
        recommendations: [], history: [], favorites: [], watchLater: [],
        account: nil, updatedAt: .distantPast, lastError: nil
    )
}

struct QRLoginSession: Sendable {
    let key: String
    let url: URL
}

enum QRLoginState: Equatable, Sendable {
    case idle
    case waiting
    case scanned
    case confirmed
    case expired
    case failed(String)
}

enum ContentSection: String, CaseIterable, Identifiable {
    case recommendations = "推荐"
    case history = "历史"
    case favorites = "收藏"
    case watchLater = "稍后再看"

    var id: String { rawValue }
}

