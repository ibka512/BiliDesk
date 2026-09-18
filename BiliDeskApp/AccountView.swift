import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            if let account = model.snapshot.account {
                AvatarView(url: account.avatarURL, size: 72)
                VStack(spacing: 6) {
                    Text(account.name).font(.title2.weight(.semibold))
                    Text("历史、收藏和稍后再看已连接")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("完成") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                    Button("退出登录", role: .destructive) {
                        Task {
                            await model.logout()
                            dismiss()
                        }
                    }
                }
            } else {
                Text("扫码登录 B 站")
                    .font(.title2.weight(.semibold))
                Group {
                    if let image = model.qrImage {
                        Image(nsImage: image)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 210, height: 210)
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    } else if case .failed(let message) = model.loginState {
                        ContentUnavailableView("无法生成二维码", systemImage: "wifi.exclamationmark", description: Text(message))
                            .frame(width: 260, height: 230)
                    } else {
                        ProgressView().frame(width: 234, height: 234)
                    }
                }
                statusText
                HStack {
                    Button("取消") {
                        model.cancelLogin()
                        dismiss()
                    }
                    if model.loginState == .expired || isFailed {
                        Button("重新生成") { Task { await model.beginLogin() } }
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(32)
        .frame(width: 420)
        .frame(minHeight: 420)
        .task {
            if !model.isLoggedIn { await model.beginLogin() }
        }
        .onDisappear { if !model.isLoggedIn { model.cancelLogin() } }
    }

    @ViewBuilder
    private var statusText: some View {
        switch model.loginState {
        case .waiting:
            Text("请使用哔哩哔哩手机 App 扫码")
        case .scanned:
            Label("已扫码，请在手机上确认", systemImage: "iphone.gen3.radiowaves.left.and.right")
                .foregroundStyle(.green)
        case .expired:
            Text("二维码已过期，请重新生成").foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        default:
            Text("登录信息只保存在这台 Mac 的钥匙串中")
        }
    }

    private var isFailed: Bool {
        if case .failed = model.loginState { return true }
        return false
    }
}
