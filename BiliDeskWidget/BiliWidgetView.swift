import AppKit
import SwiftUI
import WidgetKit

struct BiliWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BiliEntry
    private let familyOverride: WidgetFamily?

    init(entry: BiliEntry, familyOverride: WidgetFamily? = nil) {
        self.entry = entry
        self.familyOverride = familyOverride
    }

    var body: some View {
        Group {
            switch familyOverride ?? family {
            case .systemSmall: small
            case .systemMedium: medium
            case .systemLarge: large
            case .systemExtraLarge: extraLarge
            default: large
            }
        }
        .widgetURL(recommendations.first?.webURL)
    }

    private var small: some View {
        Group {
            if let video = recommendations.first {
                GeometryReader { proxy in
                    WidgetLink(destination: video.webURL) {
                        ZStack(alignment: .bottomLeading) {
                            WidgetCover(video: video, data: entry.images[video.id], cornerRadius: 0, showsDuration: false)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                            MediaTextScrim(cornerRadius: 0, endOpacity: 0.88, immersive: true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(video.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                Text(video.ownerName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(1)
                            }
                            .frame(width: max(proxy.size.width - 28, 0), alignment: .leading)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 13)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(video.accessibilityLabel)
                    .accessibilityHint("在浏览器中播放")
                    .overlay(alignment: .topLeading) {
                        compactBrand.padding(12)
                    }
                    .overlay(alignment: .topTrailing) {
                        refreshButton(inverted: true).padding(9)
                    }
                }
            } else {
                empty.padding(14)
            }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 9) {
            widgetHeader(title: "为你推荐", subtitle: updatedText)
            if let hero = recommendations.first {
                GeometryReader { proxy in
                    HStack(spacing: 10) {
                        HeroVideoCard(video: hero, data: entry.images[hero.id], showsOwner: true)
                            .frame(width: proxy.size.width * 0.58)
                        VStack(spacing: 6) {
                            ForEach(1..<3, id: \.self) { index in
                                Group {
                                    if recommendations.indices.contains(index) {
                                        RecommendationTextRow(video: recommendations[index])
                                    } else {
                                        quietPlaceholder(text: "换一批看看")
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            } else {
                empty
            }
        }
        .padding(14)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader(title: "Bili 推荐", subtitle: updatedText)
            if let hero = recommendations.first {
                GeometryReader { proxy in
                    let secondaryHeight = min(74, max(0, proxy.size.height * 0.34))
                    VStack(spacing: 8) {
                        HeroVideoCard(video: hero, data: entry.images[hero.id], showsOwner: true, prominent: true)
                            .frame(height: max(0, proxy.size.height - secondaryHeight - 8))
                        HStack(spacing: 9) {
                            ForEach(1..<3, id: \.self) { index in
                                Group {
                                    if recommendations.indices.contains(index) {
                                        let video = recommendations[index]
                                        CompactVideoCard(video: video, data: entry.images[video.id])
                                    } else {
                                        quietPlaceholder(text: "换一批看看")
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(height: secondaryHeight)
                    }
                }
                .layoutPriority(1)
            } else {
                empty.layoutPriority(1)
            }

            HStack(spacing: 9) {
                PersonalCard(title: "继续观看", icon: "clock.arrow.circlepath", video: entry.snapshot.history.first, data: imageData(for: entry.snapshot.history.first), emptyText: privateEmptyText)
                PersonalCard(title: "最近收藏", icon: "star.fill", video: entry.snapshot.favorites.first, data: imageData(for: entry.snapshot.favorites.first), emptyText: privateEmptyText)
                PersonalCard(title: "稍后再看", icon: "bookmark.fill", video: entry.snapshot.watchLater.first, data: imageData(for: entry.snapshot.watchLater.first), emptyText: privateEmptyText)
            }
            .frame(height: 80)
        }
        .padding(14)
    }

    private var extraLarge: some View {
        VStack(alignment: .leading, spacing: 9) {
            widgetHeader(title: "bilibili", subtitle: "\(updatedText) · \(recommendations.count) 条新推荐")
            GeometryReader { proxy in
                let columnSpacing: CGFloat = 12
                let sidebarWidth = max(204, proxy.size.width * 0.31)
                let recommendationHeight = max(74, proxy.size.height * 0.30)
                let heroHeight = max(0, proxy.size.height - recommendationHeight - 8)

                HStack(spacing: columnSpacing) {
                    VStack(spacing: 8) {
                        if let hero = recommendations.first {
                            DashboardHeroCard(video: hero, data: entry.images[hero.id])
                                .frame(height: heroHeight)
                        } else {
                            empty.frame(height: heroHeight)
                        }
                        HStack(spacing: 9) {
                            ForEach(Array(recommendations.dropFirst().prefix(3))) { video in
                                DashboardRecommendationCard(video: video, data: entry.images[video.id])
                            }
                        }
                        .frame(height: recommendationHeight)
                    }
                    .frame(width: max(0, proxy.size.width - sidebarWidth - columnSpacing))
                    .clipped()

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label("我的片单", systemImage: "person.crop.rectangle.stack")
                                .font(.caption.weight(.bold))
                            Spacer()
                            if !entry.snapshot.watchLater.isEmpty {
                                Text("稍后看 \(entry.snapshot.watchLater.count)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        DashboardLibraryShortcut(title: "继续观看", icon: "clock.arrow.circlepath", count: entry.snapshot.history.count, video: entry.snapshot.history.first, data: imageData(for: entry.snapshot.history.first), emptyText: privateEmptyText)
                        DashboardLibraryShortcut(title: "最近收藏", icon: "star.fill", count: entry.snapshot.favorites.count, video: entry.snapshot.favorites.first, data: imageData(for: entry.snapshot.favorites.first), emptyText: privateEmptyText)
                        DashboardLibraryShortcut(title: "稍后再看", icon: "bookmark.fill", count: entry.snapshot.watchLater.count, video: entry.snapshot.watchLater.first, data: imageData(for: entry.snapshot.watchLater.first), emptyText: privateEmptyText)
                    }
                    .padding(10)
                    .frame(width: sidebarWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .clipped()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        }
        .padding(14)
    }

    private var compactBrand: some View {
        HStack(spacing: 5) {
            BilibiliBrandIcon(color: .white)
                .frame(width: 14, height: 14)
            Text("bilibili")
                .font(.caption2.weight(.bold))
        }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.46), in: Capsule())
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            BilibiliBrandIcon()
                .frame(width: 17, height: 17)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.bold))
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            refreshButton(inverted: false)
        }
    }

    private func refreshButton(inverted: Bool) -> some View {
        Button(intent: RefreshWidgetIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(inverted ? Color.white : Color.secondary)
                .frame(width: 26, height: 26)
                .background(inverted ? Color.black.opacity(0.46) : Color.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("换一批推荐")
    }

    private var empty: some View {
        VStack(spacing: 7) {
            Image(systemName: "sparkles.tv")
                .font(.title2)
                .foregroundStyle(.pink)
            Text("打开 Bili 桌面推荐获取内容")
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func quietPlaceholder(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var recommendations: [VideoItem] { entry.snapshot.recommendations }

    private var privateEmptyText: String {
        entry.snapshot.account == nil ? "登录后显示" : "暂无内容"
    }

    private var updatedText: String {
        let date = entry.snapshot.updatedAt
        guard date > .distantPast else { return "等待首次更新" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "刚刚更新" }
        if seconds < 3_600 { return "\(seconds / 60) 分钟前更新" }
        if seconds < 86_400 { return "\(seconds / 3_600) 小时前更新" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func imageData(for video: VideoItem?) -> Data? {
        guard let video else { return nil }
        return entry.images[video.id]
    }
}

private struct DashboardHeroCard: View {
    let video: VideoItem
    let data: Data?

    var body: some View {
        GeometryReader { proxy in
            WidgetLink(destination: video.webURL) {
                VStack(spacing: 0) {
                    WidgetCover(video: video, data: data, cornerRadius: 0)
                        .frame(height: max(0, proxy.size.height - 49))
                        .clipped()
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(video.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            HStack(spacing: 7) {
                                Text(video.ownerName)
                                if let views = video.viewCountText {
                                    Label(views, systemImage: "play.fill")
                                }
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.pink)
                    }
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(MediaTitleSurface())
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .accessibilityLabel(video.accessibilityLabel)
            .accessibilityHint("在浏览器中播放")
        }
    }
}

private struct DashboardRecommendationCard: View {
    let video: VideoItem
    let data: Data?

    var body: some View {
        GeometryReader { proxy in
            let titleHeight = min(38, max(34, proxy.size.height * 0.43))
            WidgetLink(destination: video.webURL) {
                VStack(spacing: 0) {
                    WidgetCover(video: video, data: data, cornerRadius: 0)
                        .frame(height: max(0, proxy.size.height - titleHeight))
                        .clipped()
                    Text(video.title)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(MediaTitleSurface())
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
            }
            .accessibilityLabel(video.accessibilityLabel)
            .accessibilityHint("在浏览器中播放")
        }
    }
}

private struct DashboardLibraryShortcut: View {
    let title: String
    let icon: String
    let count: Int
    let video: VideoItem?
    let data: Data?
    let emptyText: String

    var body: some View {
        Group {
            if let video {
                WidgetLink(destination: video.webURL) {
                    shortcutContent(video: video)
                }
                .accessibilityLabel("\(title)，共 \(count) 条，打开最近视频")
                .accessibilityHint("在默认浏览器中播放")
            } else {
                shortcutContent(video: nil)
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func shortcutContent(video: VideoItem?) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.pink)
                .frame(width: 30, height: 30)
                .background(.pink.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                Text(count > 0 ? "\(count) 条内容" : emptyText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            if let video {
                WidgetCover(video: video, data: data, cornerRadius: 7)
                    .frame(width: 52, height: 34)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct HeroVideoCard: View {
    let video: VideoItem
    let data: Data?
    let showsOwner: Bool
    var prominent = false

    var body: some View {
        GeometryReader { proxy in
            WidgetLink(destination: video.webURL) {
                ZStack(alignment: .bottomLeading) {
                    WidgetCover(video: video, data: data, cornerRadius: 14, durationAlignment: .topTrailing)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    MediaTextScrim(cornerRadius: 14, endOpacity: 0.82)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.system(size: prominent ? 14 : 12, weight: .bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if showsOwner {
                            HStack(spacing: 6) {
                                Text(video.ownerName)
                                if let views = video.viewCountText {
                                    Label(views, systemImage: "play.fill")
                                }
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                        }
                    }
                    .frame(width: max(proxy.size.width - 22, 0), alignment: .leading)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                    .padding(11)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(video.accessibilityLabel)
            .accessibilityHint("在浏览器中播放")
        }
    }
}

private struct RecommendationTextRow: View {
    let video: VideoItem

    var body: some View {
        WidgetLink(destination: video.webURL) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(.pink)
                    .frame(width: 2, height: 24)
                Text(video.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .accessibilityLabel(video.accessibilityLabel)
        .accessibilityHint("在浏览器中播放")
    }
}

private struct CompactVideoCard: View {
    let video: VideoItem
    let data: Data?

    var body: some View {
        GeometryReader { proxy in
            WidgetLink(destination: video.webURL) {
                ZStack(alignment: .bottomLeading) {
                WidgetCover(video: video, data: data, cornerRadius: 11, durationAlignment: .topTrailing)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                MediaTextScrim(cornerRadius: 11, endOpacity: 0.76)
                Text(video.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: max(proxy.size.width - 16, 0), alignment: .leading)
                    .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                    .padding(8)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(video.accessibilityLabel)
            .accessibilityHint("在浏览器中播放")
        }
    }
}

private struct PersonalCard: View {
    let title: String
    let icon: String
    let video: VideoItem?
    let data: Data?
    let emptyText: String

    var body: some View {
        Group {
            if let video {
                GeometryReader { proxy in
                    WidgetLink(destination: video.webURL) {
                        ZStack(alignment: .bottomLeading) {
                        WidgetCover(video: video, data: data, cornerRadius: 11, durationAlignment: .topTrailing)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        MediaTextScrim(cornerRadius: 11, endOpacity: 0.82)
                        VStack(alignment: .leading, spacing: 3) {
                            Label(title, systemImage: icon)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.pink.opacity(0.95))
                            Text(video.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                        .frame(width: max(proxy.size.width - 16, 0), alignment: .leading)
                        .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                        .padding(8)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("\(title)，\(video.accessibilityLabel)")
                    .accessibilityHint("在浏览器中播放")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(title, systemImage: icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(emptyText).font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PersonalListRow: View {
    let title: String
    let icon: String
    let video: VideoItem?
    let data: Data?
    let emptyText: String

    var body: some View {
        Group {
            if let video {
                WidgetLink(destination: video.webURL) {
                    HStack(spacing: 9) {
                        WidgetCover(video: video, data: data, cornerRadius: 8)
                            .frame(width: 84, height: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Label(title, systemImage: icon)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.pink)
                            Text(video.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            if title == "继续观看", let progress = video.progress, video.duration > 0 {
                                ProgressView(value: min(Double(progress) / Double(video.duration), 1))
                                    .tint(.pink)
                                    .controlSize(.mini)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel("\(title)，\(video.accessibilityLabel)")
                .accessibilityHint("在浏览器中播放")
            } else {
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .frame(width: 84, height: 52)
                        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.caption2.weight(.semibold))
                        Text(emptyText).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetCover: View {
    let video: VideoItem
    let data: Data?
    let cornerRadius: CGFloat
    var showsDuration = true
    var durationAlignment: Alignment = .bottomTrailing

    var body: some View {
        ZStack(alignment: durationAlignment) {
            Group {
                if let data, let image = NSImage(data: data) {
                    mediaImage(image)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.31, green: 0.16, blue: 0.39), .pink.opacity(0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        BilibiliBrandIcon(color: .white.opacity(0.62))
                            .frame(width: 25, height: 25)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsDuration && !video.durationText.isEmpty {
                Text(video.durationText)
                    .font(.system(size: 8, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.68), in: Capsule())
                    .padding(5)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func mediaImage(_ image: NSImage) -> some View {
        if #available(macOS 15.0, *) {
            Image(nsImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFill()
        } else {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}

private struct MediaTextScrim: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let cornerRadius: CGFloat
    let endOpacity: Double
    var immersive = false

    var body: some View {
        let effectiveOpacity = renderingMode == .accented ? max(endOpacity, 0.90) : endOpacity
        Group {
            if immersive {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.04), location: 0),
                        .init(color: .black.opacity(0.16), location: 0.42),
                        .init(color: .black.opacity(effectiveOpacity), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [.clear, .black.opacity(effectiveOpacity)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct MediaTitleSurface: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if renderingMode == .accented {
            Color.clear
        } else {
            Color.black.opacity(0.88)
        }
    }
}

private struct WidgetSnapshotModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var widgetSnapshotMode: Bool {
        get { self[WidgetSnapshotModeKey.self] }
        set { self[WidgetSnapshotModeKey.self] = newValue }
    }
}

private struct WidgetLink<Content: View>: View {
    @Environment(\.widgetSnapshotMode) private var isSnapshot
    let destination: URL
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isSnapshot {
            content()
        } else {
            Link(destination: destination, label: content)
        }
    }
}

private extension VideoItem {
    var accessibilityLabel: String { "\(title)，UP 主 \(ownerName)" }
}
