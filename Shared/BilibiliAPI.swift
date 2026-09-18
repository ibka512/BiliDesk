import Foundation

actor BilibiliAPI {
    static let shared = BilibiliAPI()

    private let cookieStorage = HTTPCookieStorage.shared
    private let session: URLSession
    private var restoredCookies = false

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func recommendations(limit: Int = 10) async throws -> [VideoItem] {
        try restoreCookiesIfNeeded()
        let url = try makeURL(
            "https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd",
            query: ["ps": "\(limit)", "fresh_type": "3", "fresh_idx": "1"]
        )
        let payload: APIEnvelope<RecommendationData> = try await request(url)
        return payload.data?.item.compactMap { $0.videoItem } ?? []
    }

    func account() async throws -> AccountSummary? {
        try restoreCookiesIfNeeded()
        do {
            let payload: APIEnvelope<NavData> = try await request(URL(string: "https://api.bilibili.com/x/web-interface/nav")!)
            guard let data = payload.data, data.isLogin else { return nil }
            return AccountSummary(mid: data.mid, name: data.uname, avatarURL: secureURL(data.face))
        } catch BiliError.api(-101, _) {
            return nil
        }
    }

    func history(limit: Int = 8) async throws -> [VideoItem] {
        try restoreCookiesIfNeeded()
        let url = try makeURL("https://api.bilibili.com/x/web-interface/history/cursor", query: ["ps": "\(limit)"])
        let payload: APIEnvelope<HistoryData> = try await request(url)
        return payload.data?.list.compactMap { $0.videoItem } ?? []
    }

    func favorites(limit: Int = 8) async throws -> [VideoItem] {
        try restoreCookiesIfNeeded()
        guard let current = try await account() else { throw BiliError.loginRequired }
        let folderURL = try makeURL(
            "https://api.bilibili.com/x/v3/fav/folder/created/list-all",
            query: ["up_mid": "\(current.mid)"]
        )
        let folders: APIEnvelope<FavoriteFoldersData> = try await request(folderURL)
        guard let folderID = folders.data?.list?.first?.id else { return [] }
        let resourceURL = try makeURL(
            "https://api.bilibili.com/x/v3/fav/resource/list",
            query: ["media_id": "\(folderID)", "pn": "1", "ps": "\(limit)", "order": "mtime"]
        )
        let resources: APIEnvelope<FavoriteResourcesData> = try await request(resourceURL)
        return resources.data?.medias?.compactMap { $0.videoItem } ?? []
    }

    func watchLater(limit: Int = 8) async throws -> [VideoItem] {
        try restoreCookiesIfNeeded()
        let payload: APIEnvelope<WatchLaterData> = try await request(
            URL(string: "https://api.bilibili.com/x/v2/history/toview")!
        )
        return Array((payload.data?.list ?? []).compactMap { $0.videoItem }.prefix(limit))
    }

    func createQRLogin() async throws -> QRLoginSession {
        let payload: APIEnvelope<QRGenerateData> = try await request(
            URL(string: "https://passport.bilibili.com/x/passport-login/web/qrcode/generate")!
        )
        guard let data = payload.data, let url = URL(string: data.url) else { throw BiliError.invalidData }
        return QRLoginSession(key: data.qrcodeKey, url: url)
    }

    func pollQRLogin(key: String) async throws -> QRLoginState {
        let url = try makeURL(
            "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
            query: ["qrcode_key": key]
        )
        let payload: APIEnvelope<QRPollData> = try await request(url)
        guard let data = payload.data else { throw BiliError.invalidData }
        switch data.code {
        case 0:
            try persistCookies()
            return .confirmed
        case 86090: return .scanned
        case 86101: return .waiting
        case 86038: return .expired
        default: return .failed(data.message)
        }
    }

    func logout() {
        cookieStorage.cookies?.forEach(cookieStorage.deleteCookie)
        KeychainStore.delete(AppConstants.cookieKey)
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw BiliError.network
        }
        do {
            return try JSONDecoder.biliDecoder.decode(T.self, from: data)
        } catch let error as BiliError {
            throw error
        } catch {
            throw BiliError.decoding(error.localizedDescription)
        }
    }

    private func makeURL(_ string: String, query: [String: String]) throws -> URL {
        guard var components = URLComponents(string: string) else { throw BiliError.invalidData }
        components.queryItems = query.map(URLQueryItem.init(name:value:))
        guard let url = components.url else { throw BiliError.invalidData }
        return url
    }

    private func restoreCookiesIfNeeded() throws {
        guard !restoredCookies else { return }
        restoredCookies = true
        guard let data = try KeychainStore.load(AppConstants.cookieKey) else { return }
        let cookies = try JSONDecoder().decode([StoredCookie].self, from: data)
        for stored in cookies where !stored.isExpired {
            if let cookie = stored.cookie { cookieStorage.setCookie(cookie) }
        }
    }

    private func persistCookies() throws {
        let cookies = (cookieStorage.cookies ?? []).filter { $0.domain.contains("bilibili.com") }
        let data = try JSONEncoder().encode(cookies.map(StoredCookie.init))
        try KeychainStore.save(data, for: AppConstants.cookieKey)
    }
}

enum BiliError: LocalizedError {
    case network
    case invalidData
    case loginRequired
    case api(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .network: return "无法连接 B 站，请检查网络后重试。"
        case .invalidData: return "B 站返回了无法识别的数据。"
        case .loginRequired: return "请先登录 B 站账号。"
        case .api(_, let message): return message
        case .decoding: return "B 站的数据格式发生了变化，请稍后更新应用。"
        }
    }
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        message = (try? container.decode(String.self, forKey: .message)) ?? "请求失败"
        data = try? container.decode(T.self, forKey: .data)
        if code != 0 { throw BiliError.api(code, message) }
    }

    private enum CodingKeys: String, CodingKey { case code, message, data }
}

private struct RecommendationData: Decodable { let item: [RecommendationItem] }

private struct RecommendationItem: Decodable {
    let bvid: String?
    let pic: String?
    let title: String
    let duration: Int?
    let owner: Owner?
    let stat: Stat?

    var videoItem: VideoItem? {
        guard let bvid, !bvid.isEmpty else { return nil }
        return VideoItem(
            id: bvid, title: title, ownerName: owner?.name ?? "未知 UP 主",
            coverURL: secureURL(pic), duration: duration ?? 0, viewCount: stat?.view,
            progress: nil, viewedAt: nil
        )
    }
}

private struct Owner: Decodable { let name: String }
private struct Stat: Decodable { let view: Int? }
private struct NavData: Decodable {
    let isLogin: Bool
    let mid: Int64
    let uname: String
    let face: String
}

private struct HistoryData: Decodable { let list: [HistoryItem] }
private struct HistoryItem: Decodable {
    let title: String
    let cover: String?
    let authorName: String?
    let duration: Int?
    let progress: Int?
    let viewAt: Int?
    let history: HistoryIdentity?

    var videoItem: VideoItem? {
        guard let bvid = history?.bvid, !bvid.isEmpty else { return nil }
        return VideoItem(
            id: bvid, title: title, ownerName: authorName ?? "未知 UP 主",
            coverURL: secureURL(cover), duration: duration ?? 0, viewCount: nil,
            progress: progress, viewedAt: viewAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    enum CodingKeys: String, CodingKey {
        case title, cover, duration, progress, history
        case authorName = "author_name"
        case viewAt = "view_at"
    }
}
private struct HistoryIdentity: Decodable { let bvid: String? }

private struct FavoriteFoldersData: Decodable { let list: [FavoriteFolder]? }
private struct FavoriteFolder: Decodable { let id: Int64 }
private struct FavoriteResourcesData: Decodable { let medias: [FavoriteMedia]? }
private struct FavoriteMedia: Decodable {
    let bvid: String?
    let title: String
    let cover: String?
    let duration: Int?
    let upper: Owner?

    var videoItem: VideoItem? {
        guard let bvid, !bvid.isEmpty else { return nil }
        return VideoItem(
            id: bvid, title: title, ownerName: upper?.name ?? "未知 UP 主",
            coverURL: secureURL(cover), duration: duration ?? 0, viewCount: nil,
            progress: nil, viewedAt: nil
        )
    }
}

private struct WatchLaterData: Decodable { let list: [WatchLaterItem] }
private struct WatchLaterItem: Decodable {
    let bvid: String?
    let title: String
    let pic: String?
    let duration: Int?
    let owner: Owner?
    let stat: Stat?

    var videoItem: VideoItem? {
        guard let bvid, !bvid.isEmpty else { return nil }
        return VideoItem(
            id: bvid, title: title, ownerName: owner?.name ?? "未知 UP 主",
            coverURL: secureURL(pic), duration: duration ?? 0, viewCount: stat?.view,
            progress: nil, viewedAt: nil
        )
    }
}

private struct QRGenerateData: Decodable {
    let url: String
    let qrcodeKey: String
    enum CodingKeys: String, CodingKey { case url; case qrcodeKey = "qrcode_key" }
}
private struct QRPollData: Decodable { let code: Int; let message: String }

private struct StoredCookie: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool

    init(_ cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expiresDate = cookie.expiresDate
        isSecure = cookie.isSecure
    }

    var cookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path,
            .secure: isSecure ? "TRUE" : "FALSE"
        ]
        if let expiresDate { properties[.expires] = expiresDate }
        return HTTPCookie(properties: properties)
    }

    var isExpired: Bool { expiresDate.map { $0 < Date() } ?? false }
}

private func secureURL(_ string: String?) -> URL? {
    guard var string, !string.isEmpty else { return nil }
    if string.hasPrefix("http://") { string = "https://" + string.dropFirst(7) }
    return URL(string: string)
}
