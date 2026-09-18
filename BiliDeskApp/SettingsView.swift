import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("内容") {
                Toggle("应用启动时自动刷新", isOn: $model.automaticRefresh)
                Text("桌面小组件仍可通过右上角按钮随时换一批。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("播放") {
                LabeledContent("视频打开方式", value: "系统默认浏览器")
            }
            Section("隐私") {
                Text("登录凭证保存在 macOS 钥匙串中；推荐与个人列表缓存仅保存在本机。")
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
