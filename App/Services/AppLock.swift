import LocalAuthentication
import SwiftUI
import UIKit

/// **앱 잠금** (FR-029 · D-51) — Face ID · Touch ID · 기기 암호로 앱을 연다. 기본은 꺼짐.
///
/// - 켜 두면 앱을 처음 열 때와 **뒤로 갔다 돌아올 때** 확인한다. 알림 센터를 내리는 정도(잠깐 비활성)는 잠그지 않고 가리기만 한다.
/// - 가리개는 **앱 창들 위의 따로 만든 창**이다 — 사람 수정 같은 시트가 떠 있어도 그 위를 덮는다(뿌리 화면에 얹으면 시트가 위로 나온다).
///   앱 전환기의 미리보기에도 가리개가 찍힌다.
/// - 이번 잠금에서 확인 창은 **한 번만 저절로** 띄운다 — 취소하면 가리개의 `잠금 풀기` 단추로 다시.
/// - 기기 암호를 지워 확인할 길이 없어지면 앱을 막지 않고 연다(영영 못 여는 일이 없게).
/// - 얼굴 · 지문은 기기가 확인한다. 앱은 맞다 · 아니다만 받는다.
@MainActor
@Observable
final class AppLock {
    static let shared = AppLock()
    static let enabledKey = "lock.enabled"

    /// 잠겨 있나 — 풀기 전까지 가리개가 덮는다.
    private(set) var isLocked: Bool
    /// 확인 창이 떠 있나.
    private(set) var isAuthenticating = false
    @ObservationIgnored private var autoPrompted = false
    @ObservationIgnored private var windows: [UIWindow] = []

    private init() {
        // 첫 화면이 그려지기 전에 정한다 — 잠금을 켜 두었으면 한 장면도 보이지 않게.
        isLocked = UserDefaults.standard.bool(forKey: Self.enabledKey) || LaunchArguments.current.previewLock
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    /// 이 기기에서 쓸 수 있는 확인 방법의 이름. 기기 암호조차 없으면 `nil` — 잠금을 켤 수 없다.
    nonisolated static func methodName() -> String? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return nil }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "기기 암호"
        }
    }

    /// 기기에 확인을 맡긴다 — 생체 인식이 안 되면 기기 암호로 넘어간다.
    nonisolated static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    /// 뿌리 화면이 처음 뜰 때.
    func launch(isActive: Bool) {
        // CI 스크린샷 — 가리개 모양만 (확인 창은 시뮬레이터에서 띄우지 않는다).
        if LaunchArguments.current.previewLock {
            isLocked = true
            return
        }
        guard isEnabled else {
            isLocked = false
            return
        }
        isLocked = true
        autoPrompted = false
        cover()
        if isActive { promptOnce() }
    }

    func phaseChanged(_ phase: ScenePhase) {
        if LaunchArguments.current.previewLock { return }
        guard isEnabled else {
            isLocked = false
            uncover()
            return
        }
        switch phase {
        case .background:
            if !isAuthenticating {
                isLocked = true
                autoPrompted = false
            }
            cover()
        case .inactive:
            cover()
        case .active:
            if isLocked {
                cover()
                promptOnce()
            } else if !isAuthenticating {
                uncover()
            }
        @unknown default:
            break
        }
    }

    /// 가리개의 `잠금 풀기` 단추 · 저절로 띄우기가 함께 부른다.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        guard Self.methodName() != nil else {
            isLocked = false
            uncover()
            return
        }
        isAuthenticating = true
        let passed = await Self.authenticate(reason: "잠금을 풀고 인연 기록을 엽니다")
        isAuthenticating = false
        if passed {
            isLocked = false
            uncover()
        }
    }

    private func promptOnce() {
        guard !autoPrompted else { return }
        autoPrompted = true
        Task { await unlock() }
    }

    private func cover() {
        guard windows.isEmpty else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            let host = UIHostingController(rootView: LockScreen(lock: self))
            window.rootViewController = host
            window.isHidden = false
            windows.append(window)
        }
    }

    private func uncover() {
        for window in windows { window.isHidden = true }
        windows = []
    }
}

/// 가리개 — 앱 이름과 자물쇠. 잠겨 있으면 `잠금 풀기` 단추.
struct LockScreen: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Color.ground.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.scaledCapped(40))
                    .foregroundStyle(Color.accent)
                    .accessibilityHidden(true)
                Text("느린 인연")
                    .font(.scaled(22, weight: .semibold))
                    .foregroundStyle(Color.ink)
                if lock.isLocked {
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("잠금 풀기", systemImage: "lock.open")
                            .font(.scaled(17, weight: .semibold))
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accent)
                    .disabled(lock.isAuthenticating)
                }
            }
            .padding(24)
        }
    }
}
