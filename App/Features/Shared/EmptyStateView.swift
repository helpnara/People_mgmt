import SwiftUI

/// 등록된 사람이 없을 때 (요구사항 7.1-6 · FR-020). 앱의 목적과 첫 등록 방법을 말한다.
/// 아래의 `견본으로 둘러보기` 는 지어낸 자료로 앱을 먼저 본다 (D-55 · 심사와 처음 쓰는 사람).
struct EmptyPeopleView: View {
    let onAdd: () -> Void
    var onDemo: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("아직 등록한 사람이 없습니다", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("이 사람을 어떻게 알게 되었고 어떤 시간을 함께했는지 기록하는 앱입니다. 이름 하나로 시작할 수 있습니다.")
        } actions: {
            Button("첫 사람 등록하기", action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
            if let onDemo {
                VStack(spacing: 6) {
                    Button("견본으로 둘러보기", action: onDemo)
                        .buttonStyle(.bordered)
                        .tint(Color.accent)
                        .accessibilityHint("지어낸 사람과 기록으로 앱을 먼저 봅니다. 저장되지 않습니다")
                    Text("지어낸 사람과 기록으로 먼저 둘러봅니다. 내 자료와 섞이지 않고, 끝내면 사라집니다.")
                        .font(.scaled(12))
                        .foregroundStyle(Color.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
        }
    }
}
