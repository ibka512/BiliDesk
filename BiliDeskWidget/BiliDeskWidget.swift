import AppIntents
import AppKit
import ImageIO
import SwiftUI
import WidgetKit

@main
struct BiliDeskWidgetBundle: WidgetBundle {
    var body: some Widget {
        BiliDeskWidget()
    }
}

struct BiliDeskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKind, provider: BiliTimelineProvider()) { entry in
            BiliWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        LinearGradient(
                            colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.09), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
        }
        .configurationDisplayName("Bili 桌面推荐")
        .description("查看首页推荐，并快速打开历史、收藏与稍后再看。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

struct BiliEntry: TimelineEntry {
    let date: Date
    let snapshot: ContentSnapshot
    let images: [String: Data]
}

struct BiliTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BiliEntry {
        BiliEntry(date: Date(), snapshot: .preview, images: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (BiliEntry) -> Void) {
        let box = CompletionBox(completion)
        let isPreview = context.isPreview
        Task { box.call(await makeEntry(preview: isPreview)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BiliEntry>) -> Void) {
        let box = CompletionBox(completion)
        Task {
            let entry = await makeEntry(preview: false)
            let next = Calendar.current.date(byAdding: .minute, value: 45, to: Date()) ?? Date().addingTimeInterval(2700)
            box.call(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func makeEntry(preview: Bool) async -> BiliEntry {
        let snapshot = preview ? ContentSnapshot.preview : SharedSnapshotStore.load()
        let allVideos = Array((snapshot.recommendations.prefix(6)
            + snapshot.history.prefix(1)
            + snapshot.favorites.prefix(1)
            + snapshot.watchLater.prefix(1)))
        let uniqueVideos = Dictionary(
            allVideos.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values
        var images: [String: Data] = [:]
        await withTaskGroup(of: (String, Data?).self) { group in
            for video in uniqueVideos {
                group.addTask {
                    let cached = WidgetImageCache.load(id: video.id)
                    guard let url = video.coverURL else { return (video.id, cached) }
                    var request = URLRequest(
                        url: url,
                        cachePolicy: .returnCacheDataElseLoad,
                        timeoutInterval: 12
                    )
                    request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
                    request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
                    guard let (data, response) = try? await URLSession.shared.data(for: request),
                          let http = response as? HTTPURLResponse,
                          200..<300 ~= http.statusCode,
                          let imageData = WidgetImageCache.downsample(data: data) else {
                        return (video.id, cached)
                    }
                    WidgetImageCache.save(imageData, id: video.id)
                    return (video.id, imageData)
                }
            }
            for await (id, data) in group {
                if let data { images[id] = data }
            }
        }
        WidgetImageCache.prune(keeping: Set(uniqueVideos.map(\.id)))
        return BiliEntry(date: Date(), snapshot: snapshot, images: images)
    }
}

private final class CompletionBox<Value>: @unchecked Sendable {
    private let completion: (Value) -> Void
    init(_ completion: @escaping (Value) -> Void) { self.completion = completion }
    func call(_ value: Value) { completion(value) }
}

struct RefreshWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "刷新 Bili 推荐"
    static let description = IntentDescription("获取一批新的首页推荐，并更新个人内容。")

    func perform() async throws -> some IntentResult {
        _ = await ContentRefreshService.refresh(includePrivateContent: true)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        return .result()
    }
}

private enum WidgetImageCache {
    private static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroup)?
            .appendingPathComponent("WidgetCovers", isDirectory: true)
    }

    static func load(id: String) -> Data? {
        guard let url = fileURL(id: id) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func save(_ data: Data, id: String) {
        guard let directory, let url = fileURL(id: id) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func prune(keeping ids: Set<String>) {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
              ) else { return }
        for file in files where !ids.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func downsample(data: Data) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 720,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.78])
    }

    private static func fileURL(id: String) -> URL? {
        let safeID = id.replacingOccurrences(of: "/", with: "_")
        return directory?.appendingPathComponent(safeID).appendingPathExtension("jpg")
    }
}

extension ContentSnapshot {
    static let preview = ContentSnapshot(
        recommendations: [
            .init(id: "BV1preview01", title: "桌面上的新鲜推荐，从这里开始", ownerName: "哔哩桌面", coverURL: nil, duration: 328, viewCount: 123_000, progress: nil, viewedAt: nil),
            .init(id: "BV1preview02", title: "第二条值得一看的内容", ownerName: "创作者", coverURL: nil, duration: 92, viewCount: 48_000, progress: nil, viewedAt: nil)
        ],
        history: [.init(id: "BV1history", title: "上次看到这里", ownerName: "UP 主", coverURL: nil, duration: 600, viewCount: nil, progress: 280, viewedAt: Date())],
        favorites: [.init(id: "BV1favorite", title: "最近收藏的视频", ownerName: "UP 主", coverURL: nil, duration: 240, viewCount: nil, progress: nil, viewedAt: nil)],
        watchLater: [.init(id: "BV1later", title: "稍后再看", ownerName: "UP 主", coverURL: nil, duration: 420, viewCount: nil, progress: nil, viewedAt: nil)],
        account: nil,
        updatedAt: Date(),
        lastError: nil
    )
}
