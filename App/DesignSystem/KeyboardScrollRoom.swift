import SwiftUI
import UIKit

/// **키보드가 가린 만큼 스크롤 끝에 여백** (이슈 80 · 2026-11-04 사용자 — 기록 추가에서 키보드가 올라온 채로는
/// 아래 칸(함께한 사람 · 태그)까지 내려가지 못하고 튕겨 돌아왔다).
///
/// 실기기 화면 녹화를 8장/초로 잘라 보니 스크롤 끝이 **화면 맨 아래(홈 막대 위)** 에 있었다 — 키보드 높이만큼의 아래 여백이
/// 양식에 들어오지 않아, 마지막 칸들이 키보드 뒤에 숨은 채 더 내려갈 수 없었다. 시스템이 키보드를 피해 주는 화면도 있고
/// 아닌 화면도 있어(시트 · 키보드를 끌어 내리는 양식) **모자란 만큼만** 채운다:
///
///     더할 여백 = 이 칸의 아래 끝 − 키보드 위 끝 − 이 칸이 이미 받은 아래 안전 영역
///
/// 시스템이 키보드를 피해 주면 칸이 줄거나 안전 영역이 키보드만큼 커져 0 이 되고, 피해 주지 않으면 키보드에 가린 높이가 된다.
/// 스크롤 내용에만 여백을 준다(`contentMargins`) — 칸의 크기 · 배경은 그대로다. 키보드가 내려가면 0.
private struct KeyboardScrollRoom: ViewModifier {
    /// 키보드 위 끝(화면 좌표). 키보드가 없으면 nil.
    @State private var keyboardTop: CGFloat?
    /// 이 칸의 아래 끝(화면 좌표)과 이미 받은 아래 안전 영역.
    @State private var frameBottom: CGFloat = 0
    @State private var safeBottom: CGFloat = 0

    private var room: CGFloat {
        guard let keyboardTop else { return 0 }
        return max(0, frameBottom - keyboardTop - safeBottom)
    }

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, room, for: .scrollContent)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { measure(proxy) }
                        .onChange(of: proxy.frame(in: .global).maxY) { _, _ in measure(proxy) }
                        .onChange(of: proxy.safeAreaInsets.bottom) { _, _ in measure(proxy) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                // 화면 밖으로 내려간 키보드(끌어 내림 · 하드웨어 키보드)는 위 끝이 칸 아래라 여백이 0 이 된다.
                keyboardTop = end.height > 0 ? end.minY : nil
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardTop = nil
            }
    }

    private func measure(_ proxy: GeometryProxy) {
        frameBottom = proxy.frame(in: .global).maxY
        safeBottom = proxy.safeAreaInsets.bottom
    }
}

extension View {
    /// 글을 넣는 목록 · 양식에 붙인다 — 키보드가 올라와도 마지막 칸까지 내려갈 수 있다 (이슈 80).
    func keyboardScrollRoom() -> some View { modifier(KeyboardScrollRoom()) }
}
