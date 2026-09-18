import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: ContentSnapshot
    @Published private(set) var isRefreshing = false
    @Published private(set) var loginState: QRLoginState = .idle
    @Published private(set) var qrImage: NSImage?
    @Published var selectedSection: ContentSection = .recommendations
    @Published var isMainWindowPresented = false
    @AppStorage("automaticRefresh") var automaticRefresh = true

    private var qrSession: QRLoginSession?
    private var pollTask: Task<Void, Never>?

    init() {
        snapshot = SharedSnapshotStore.load()
    }

    var isLoggedIn: Bool { snapshot.account != nil }

    func start() async {
        if automaticRefresh || snapshot.recommendations.isEmpty {
            await refresh()
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        snapshot = await ContentRefreshService.refresh(includePrivateContent: true)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        isRefreshing = false
    }

    func beginLogin() async {
        pollTask?.cancel()
        loginState = .waiting
        do {
            let session = try await BilibiliAPI.shared.createQRLogin()
            qrSession = session
            qrImage = makeQRCode(from: session.url.absoluteString)
            pollTask = Task { [weak self] in
                await self?.pollLogin(session)
            }
        } catch {
            loginState = .failed(error.localizedDescription)
        }
    }

    func cancelLogin() {
        pollTask?.cancel()
        pollTask = nil
        qrSession = nil
        qrImage = nil
        loginState = .idle
    }

    func logout() async {
        await BilibiliAPI.shared.logout()
        var next = snapshot
        next.account = nil
        next.history = []
        next.favorites = []
        next.watchLater = []
        try? SharedSnapshotStore.save(next)
        snapshot = next
        WidgetCenter.shared.reloadAllTimelines()
    }

    func open(_ video: VideoItem) {
        NSWorkspace.shared.open(video.webURL)
    }

    func videos(for section: ContentSection) -> [VideoItem] {
        switch section {
        case .recommendations: snapshot.recommendations
        case .history: snapshot.history
        case .favorites: snapshot.favorites
        case .watchLater: snapshot.watchLater
        }
    }

    private func pollLogin(_ session: QRLoginSession) async {
        while !Task.isCancelled {
            do {
                let state = try await BilibiliAPI.shared.pollQRLogin(key: session.key)
                loginState = state
                if state == .confirmed {
                    await refresh()
                    qrImage = nil
                    return
                }
                if state == .expired { return }
            } catch {
                loginState = .failed(error.localizedDescription)
                return
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func makeQRCode(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else {
            return nil
        }
        let representation = NSCIImageRep(ciImage: output)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }
}
