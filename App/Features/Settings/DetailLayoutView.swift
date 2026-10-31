import Core
import SwiftUI

/// **상세 화면 칸** (D-56 · 2026-10-27 사용자) — 사람 상세의 칸 차례를 끌어 바꾸고, 칸마다 보이기를 끄고 켠다.
///
/// - 맨 위의 사진 · 이름 · 소속 · 연락 수단 칸은 늘 맨 위다 — 여기 들지 않는다.
/// - 이 기기에만 둔다(`UserDefaults`). 규칙은 `Core.DetailLayout` 하나(정답표 `detailLayout` · `detailMove`).
/// - 숨겨도 자료는 그대로다.
struct DetailLayoutView: View {
    static let storageKey = "detail.layout"

    @AppStorage(DetailLayoutView.storageKey) private var stored = ""

    var body: some View {
        let layout = DetailLayout(stored: stored)
        List {
            Section {
                ForEach(layout.order) { section in
                    Toggle(isOn: visibility(of: section)) {
                        Text(section.label)
                            .font(.scaled(16))
                            .foregroundStyle(Color.ink)
                    }
                    .tint(Color.accent)
                    .accessibilityHint("끌어서 차례를 바꿉니다. 끄면 사람 상세에서 이 칸이 보이지 않습니다")
                }
                .onMove { source, destination in
                    var changed = DetailLayout(stored: stored)
                    changed.move(fromOffsets: source, toOffset: destination)
                    stored = changed.stored
                }
            } header: {
                Text("사진 · 이름 칸 아래의 차례")
            } footer: {
                Text("오른쪽 손잡이를 끌어 차례를 바꾸고, 스위치를 끄면 그 칸이 사람 상세에서 보이지 않습니다. 숨긴 칸의 자료는 지워지지 않습니다. 자료가 없는 칸(명함 · 소개한 인연 · 아는 사이)은 전처럼 나타나지 않습니다. 맨 위의 사진 · 이름 · 소속 · 연락 수단 칸은 늘 맨 위입니다. 이 기기에만 적용됩니다.")
            }
            Section {
                Button("처음 차례로") { stored = "" }
                    .disabled(layout == .standard)
            }
        }
        // 손잡이가 늘 보이게 — 편집 단추를 따로 누르지 않는다. 지우기 단추는 없다(`onDelete` 를 두지 않음).
        .environment(\.editMode, .constant(.active))
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ground)
        .navigationTitle("상세 화면 칸")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func visibility(of section: DetailSection) -> Binding<Bool> {
        Binding {
            !DetailLayout(stored: stored).isHidden(section)
        } set: { show in
            var changed = DetailLayout(stored: stored)
            changed.setHidden(section, !show)
            stored = changed.stored
        }
    }
}
