import AppKit
import SwiftUI

struct DesktopDashboardView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("dashboardWindowMode") private var windowModeRaw = DashboardWindowMode.desktop.rawValue
    @State private var selectedLibrary: ContentSection = .history

    private var windowMode: DashboardWindowMode {
        DashboardWindowMode(rawValue: windowModeRaw) ?? .desktop
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = DashboardMetrics(size: proxy.size)
            VStack(spacing: metrics.sectionSpacing) {
                dashboardHeader
                    .frame(height: metrics.headerHeight)
                HStack(spacing: metrics.sectionSpacing) {
                    heroArea
                    libraryPanel
                        .frame(width: metrics.libraryWidth)
                }
                .frame(height: metrics.featureHeight)
                recommendationStrip(count: metrics.recommendationCount)
                    .frame(maxHeight: .infinity)
            }
            .padding(metrics.outerPadding)
        }
        .frame(minWidth: 820, minHeight: 480)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [.pink.opacity(0.07), .purple.opacity(0.06), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .background(DashboardWindowAccessor(mode: windowMode))
    }

    private var dashboardHeader: some View {
        HStack(spacing: 12) {
            BilibiliBrandIcon()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("bilibili")
                    .font(.headline.weight(.bold))
                Text(updatedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let error = model.snapshot.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
                    .accessibilityLabel("同步出现问题：\(error)")
            }
            Menu {
                ForEach(DashboardWindowMode.allCases) { mode in
                    Button {
                        windowModeRaw = mode.rawValue
                    } label: {
                        if mode == windowMode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                Label(windowMode.title, systemImage: windowMode.icon)
            }
            .menuStyle(.borderlessButton)
            .help("设置看板窗口显示方式")

            Button {
                Task { await model.refresh() }
            } label: {
                Label(model.isRefreshing ? "正在刷新" : "换一批", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRefreshing)
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    @ViewBuilder
    private var heroArea: some View {
        if let hero = model.snapshot.recommendations.first {
            DashboardHero(video: hero) { model.open(hero) }
        } else if model.isRefreshing {
            ProgressView("正在获取推荐…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            ContentUnavailableView("暂时没有推荐", systemImage: "sparkles.tv", description: Text("点击右上角刷新后再试。"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("我的片单", systemImage: "person.crop.rectangle.stack")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(model.videos(for: selectedLibrary).count) 条")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Picker("片单类别", selection: $selectedLibrary) {
                Text("历史").tag(ContentSection.history)
                Text("收藏").tag(ContentSection.favorites)
                Text("稍后再看").tag(ContentSection.watchLater)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            let videos = model.videos(for: selectedLibrary)
            if videos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: libraryIcon)
                        .font(.title2)
                    Text(model.isLoggedIn ? "这里还没有内容" : "登录后显示个人片单")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(videos.prefix(3))) { video in
                        DashboardLibraryRow(video: video) { model.open(video) }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(14)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func recommendationStrip(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("更多推荐")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("点击视频将在默认浏览器中播放")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                ForEach(Array(model.snapshot.recommendations.dropFirst().prefix(count))) { video in
                    DashboardRecommendation(video: video) { model.open(video) }
                }
            }
        }
    }

    private var libraryIcon: String {
        switch selectedLibrary {
        case .history: "clock.arrow.circlepath"
        case .favorites: "star"
        case .watchLater: "bookmark"
        case .recommendations: "sparkles.tv"
        }
    }

    private var updatedText: String {
        guard model.snapshot.updatedAt > .distantPast else { return "等待首次更新" }
        return "更新于 \(model.snapshot.updatedAt.formatted(date: .omitted, time: .shortened)) · \(model.snapshot.recommendations.count) 条推荐"
    }
}

private struct DashboardHero: View {
    let video: VideoItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                let infoHeight = min(76, max(64, proxy.size.height * 0.22))
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteImage(url: video.coverURL)
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: max(0, proxy.size.height - infoHeight))
                            .clipped()
                        durationBadge
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.title3.weight(.bold))
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
                        Spacer(minLength: 8)
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.pink)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("推荐视频，\(video.title)，UP 主 \(video.ownerName)")
        .accessibilityHint("在默认浏览器中播放")
    }

    @ViewBuilder
    private var durationBadge: some View {
        if !video.durationText.isEmpty {
            Text(video.durationText)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black.opacity(0.72), in: Capsule())
                .padding(9)
        }
    }
}

private struct DashboardLibraryRow: View {
    let video: VideoItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack(alignment: .bottomTrailing) {
                    RemoteImage(url: video.coverURL)
                        .scaledToFill()
                        .frame(width: 112, height: 63)
                        .clipped()
                    if !video.durationText.isEmpty {
                        Text(video.durationText)
                            .font(.system(size: 9, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.72), in: Capsule())
                            .padding(5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(video.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    Text(video.ownerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(video.title)，UP 主 \(video.ownerName)")
        .accessibilityHint("在默认浏览器中播放")
    }
}

private struct DashboardRecommendation: View {
    let video: VideoItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                let titleHeight = min(48, max(38, proxy.size.height * 0.32))
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteImage(url: video.coverURL)
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: max(0, proxy.size.height - titleHeight))
                            .clipped()
                        if !video.durationText.isEmpty {
                            Text(video.durationText)
                                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.72), in: Capsule())
                                .padding(6)
                        }
                    }
                    Text(video.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .background(Color(nsColor: .controlBackgroundColor))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("推荐视频，\(video.title)")
        .accessibilityHint("在默认浏览器中播放")
    }
}

private struct DashboardMetrics {
    let size: CGSize

    var outerPadding: CGFloat { size.width >= 1100 ? 20 : 16 }
    var sectionSpacing: CGFloat { size.width >= 1100 ? 16 : 12 }
    var headerHeight: CGFloat { 48 }
    var libraryWidth: CGFloat { min(390, max(310, size.width * 0.34)) }
    var recommendationCount: Int {
        if size.width >= 1220 { return 5 }
        if size.width >= 940 { return 4 }
        return 3
    }
    var featureHeight: CGFloat {
        let available = size.height - outerPadding * 2 - headerHeight - sectionSpacing * 2
        return min(max(245, available * 0.66), max(245, available - 130))
    }
}

private enum DashboardWindowMode: String, CaseIterable, Identifiable {
    case desktop
    case normal
    case floating

    var id: String { rawValue }
    var title: String {
        switch self {
        case .desktop: "驻留桌面"
        case .normal: "普通窗口"
        case .floating: "保持置顶"
        }
    }
    var icon: String {
        switch self {
        case .desktop: "desktopcomputer"
        case .normal: "macwindow"
        case .floating: "pin.fill"
        }
    }
}

private struct DashboardWindowAccessor: NSViewRepresentable {
    let mode: DashboardWindowMode

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.setFrameAutosaveName("BiliDeskDesktopDashboard")
        window.isReleasedWhenClosed = false
        switch mode {
        case .desktop:
            window.level = .normal
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        case .normal:
            window.level = .normal
            window.collectionBehavior = [.managed, .participatesInCycle]
        case .floating:
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
    }
}
