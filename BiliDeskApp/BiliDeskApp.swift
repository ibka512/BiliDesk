import AppKit
import SwiftUI

@MainActor
private enum AppPresentationController {
    static var allowsVisibleWindows = SharedSnapshotStore.load().account == nil
    static var pendingVideoURL: URL?

    static func showWindows() {
        allowsVisibleWindows = true
        NSApp.windows.forEach {
            $0.alphaValue = 1
            $0.isOpaque = true
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hideWindows() {
        allowsVisibleWindows = false
        NSApp.windows.forEach {
            $0.alphaValue = 0
            $0.isOpaque = false
            $0.orderOut(nil)
        }
        NSApp.hide(nil)
    }
}

@MainActor
private enum WidgetVideoLinkRouter {
    private static var lastOpenedURL: URL?
    private static var lastOpenedAt = Date.distantPast

    static func openInBrowserIfNeeded(_ url: URL) {
        guard isBilibiliVideoURL(url) else { return }

        let now = Date()
        guard url != lastOpenedURL || now.timeIntervalSince(lastOpenedAt) > 1 else {
            return
        }
        lastOpenedURL = url
        lastOpenedAt = now

        if SharedSnapshotStore.load().account == nil {
            AppPresentationController.pendingVideoURL = url
            AppPresentationController.showWindows()
        } else {
            AppPresentationController.hideWindows()
            NSWorkspace.shared.open(url)
        }
    }

    static func finishPendingLoginIfNeeded() {
        guard let url = AppPresentationController.pendingVideoURL else {
            AppPresentationController.hideWindows()
            return
        }
        AppPresentationController.pendingVideoURL = nil
        AppPresentationController.hideWindows()
        NSWorkspace.shared.open(url)
    }

    private static func isBilibiliVideoURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              host == "bilibili.com" || host.hasSuffix(".bilibili.com")
        else {
            return false
        }

        return url.path.lowercased().hasPrefix("/video/")
    }
}

private final class BiliDeskAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppPresentationController.allowsVisibleWindows {
            AppPresentationController.showWindows()
        } else {
            AppPresentationController.hideWindows()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            WidgetVideoLinkRouter.openInBrowserIfNeeded(url)
        }
    }

}

@main
struct BiliDeskApp: App {
    @NSApplicationDelegateAdaptor(BiliDeskAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("BiliDesk", id: "main") {
            AppRootView()
                .environmentObject(model)
                .task { await model.start() }
                .onOpenURL { url in
                    WidgetVideoLinkRouter.openInBrowserIfNeeded(url)
                }
        }
        .windowStyle(.titleBar)
        .commands {
            DashboardCommands()
        }

        MenuBarExtra("BiliDesk", systemImage: "play.rectangle.fill") {
            MenuBarControlView()
                .environmentObject(model)
        }

        Window("bilibili", id: "desktop-dashboard") {
            DesktopDashboardView()
                .environmentObject(model)
        }
        .defaultSize(width: 960, height: 560)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 480, height: 320)
        }
    }
}

private struct AppRootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if !model.isLoggedIn {
                AccountView()
                    .frame(width: 420)
                    .frame(minHeight: 420)
                    .background(WindowVisibilityBridge(isVisible: true))
            } else if model.isMainWindowPresented {
                ContentView()
                    .frame(minWidth: 860, minHeight: 620)
                    .background(WindowVisibilityBridge(isVisible: true))
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
                    .background(WindowVisibilityBridge(isVisible: false))
            }
        }
        .onChange(of: model.isLoggedIn) { wasLoggedIn, isLoggedIn in
            if !wasLoggedIn && isLoggedIn {
                model.isMainWindowPresented = false
                WidgetVideoLinkRouter.finishPendingLoginIfNeeded()
            } else if wasLoggedIn && !isLoggedIn {
                AppPresentationController.showWindows()
            }
        }
    }
}

private struct WindowVisibilityBridge: NSViewRepresentable {
    let isVisible: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        update(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        update(nsView)
    }

    private func update(_ view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if isVisible {
                AppPresentationController.showWindows()
                window.alphaValue = 1
                window.isOpaque = true
                window.makeKeyAndOrderFront(nil)
            } else {
                AppPresentationController.hideWindows()
            }
        }
    }
}

private struct MenuBarControlView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.isLoggedIn {
            Button("打开 BiliDesk") {
                model.isMainWindowPresented = true
                openWindow(id: "main")
                AppPresentationController.showWindows()
            }
            Button("打开视频看板") {
                AppPresentationController.showWindows()
                openWindow(id: "desktop-dashboard")
            }
        } else {
            Button("扫码登录") {
                openWindow(id: "main")
                AppPresentationController.showWindows()
            }
        }
        Divider()
        Button("退出 BiliDesk") {
            NSApp.terminate(nil)
        }
    }
}

private struct DashboardCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("打开桌面看板") {
                openWindow(id: "desktop-dashboard")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
