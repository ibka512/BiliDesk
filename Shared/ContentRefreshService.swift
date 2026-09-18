import Foundation

enum ContentRefreshService {
    static func refresh(includePrivateContent: Bool = true) async -> ContentSnapshot {
        let api = BilibiliAPI.shared
        var snapshot = SharedSnapshotStore.load()
        var firstError: String?

        do { snapshot.recommendations = try await api.recommendations() }
        catch { firstError = error.localizedDescription }

        if includePrivateContent {
            do {
                snapshot.account = try await api.account()
                if snapshot.account != nil {
                    async let history = api.history()
                    async let favorites = api.favorites()
                    async let watchLater = api.watchLater()
                    do { snapshot.history = try await history } catch { firstError = firstError ?? error.localizedDescription }
                    do { snapshot.favorites = try await favorites } catch { firstError = firstError ?? error.localizedDescription }
                    do { snapshot.watchLater = try await watchLater } catch { firstError = firstError ?? error.localizedDescription }
                }
            } catch {
                firstError = firstError ?? error.localizedDescription
            }
        }

        snapshot.updatedAt = Date()
        snapshot.lastError = firstError
        try? SharedSnapshotStore.save(snapshot)
        return snapshot
    }
}
