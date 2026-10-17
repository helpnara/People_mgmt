import SwiftUI

/// 등록된 사람이 없을 때 (요구사항 7.1-6 · FR-020). 앱의 목적과 첫 등록 방법을 말한다.
struct EmptyPeopleView: View {
    let onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("아직 등록한 사람이 없습니다", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("이 사람을 어떻게 알게 되었고 어떤 시간을 함께했는지 기록하는 앱입니다. 이름 하나로 시작할 수 있습니다.")
        } actions: {
            Button("첫 사람 등록하기", action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
        }
    }
}
