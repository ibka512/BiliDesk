import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var showAccount = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            dashboard
        }
        .sheet(isPresented: $showAccount) {
            AccountView()
                .environmentObject(model)
        }
    }

    private var sidebar: some View {
        List(selection: $model.selectedSection) {
            Section("浏览") {
                Label("首页推荐", systemImage: "sparkles.tv")
                    .tag(ContentSection.recommendations)
                Label("历史记录", systemImage: "clock.arrow.circlepath")
                    .tag(ContentSection.history)
                Label("收藏视频", systemImage: "star")
                    .tag(ContentSection.favorites)
                Label("稍后再看", systemImage: "bookmark")
                    .tag(ContentSection.watchLater)
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        .safeAreaInset(edge: .bottom) {
            Button {
                showAccount = true
            } label: {
                HStack(spacing: 10) {
                    AvatarView(url: model.snapshot.account?.avatarURL, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.snapshot.account?.name ?? "登录 B 站")
                            .font(.callout.weight(.medium))
                        Text(model.isLoggedIn ? "账号已连接" : "同步历史、收藏与稍后再看")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.selectedSection.rawValue)
                    .font(.title2.weight(.semibold))
                if model.snapshot.updatedAt > .distantPast {
                    Text("更新于 \(model.snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let error = model.snapshot.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .help(error)
            }
            Button {
                openWindow(id: "desktop-dashboard")
            } label: {
                Label("桌面看板", systemImage: "rectangle.inset.filled")
            }
            .help("打开可以自由缩放的视频看板")
            Button {
                Task { await model.refresh() }
            } label: {
                Label(model.isRefreshing ? "正在刷新" : "换一批", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRefreshing)
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var content: some View {
        let videos = model.videos(for: model.selectedSection)
        if model.isRefreshing && videos.isEmpty {
            ProgressView("正在获取内容…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if videos.isEmpty {
            EmptySectionView(section: model.selectedSection, isLoggedIn: model.isLoggedIn) {
                showAccount = true
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 340), spacing: 18)], spacing: 20) {
                    ForEach(videos) { video in
                        VideoCard(video: video) { model.open(video) }
                    }
                }
                .padding(24)
            }
        }
    }
}

private struct VideoCard: View {
    let video: VideoItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    RemoteImage(url: video.coverURL)
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    if !video.durationText.isEmpty {
                        Text(video.durationText)
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.72), in: Capsule())
                            .padding(7)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text(video.ownerName)
                    if let views = video.viewCountText {
                        Text("·")
                        Label(views, systemImage: "play.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(video.title)，UP 主 \(video.ownerName)")
        .accessibilityHint("在默认浏览器中播放")
    }
}

struct RemoteImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable()
            case .failure:
                placeholder(systemName: "photo")
            default:
                ZStack {
                    Color.secondary.opacity(0.1)
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    private func placeholder(systemName: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [.pink.opacity(0.2), .purple.opacity(0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: systemName)
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct EmptySectionView: View {
    let section: ContentSection
    let isLoggedIn: Bool
    let login: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
        } actions: {
            if section != .recommendations && !isLoggedIn {
                Button("扫码登录", action: login)
            }
        }
    }

    private var title: String { section == .recommendations ? "暂时没有推荐" : "这里还没有内容" }
    private var icon: String {
        switch section {
        case .recommendations: "sparkles.tv"
        case .history: "clock.arrow.circlepath"
        case .favorites: "star"
        case .watchLater: "bookmark"
        }
    }
    private var description: String {
        if section != .recommendations && !isLoggedIn { return "登录 B 站后即可同步\(section.rawValue)。" }
        return "稍后刷新再试，已有缓存不会被清除。"
    }
}
