import Foundation
import Security

enum AppConstants {
    static var appGroup: String {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.security.application-groups" as CFString,
                nil
              ),
              let groups = value as? [String],
              let group = groups.first else {
            return "group.com.local.BiliDesk"
        }
        return group
    }
    static let widgetKind = "BiliDeskRecommendations"
    static let snapshotFilename = "snapshot.json"
    static let cookieKey = "bilibili.cookies"
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140 Safari/537.36"
}
