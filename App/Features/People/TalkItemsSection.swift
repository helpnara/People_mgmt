import Core
import SwiftData
import SwiftUI

/// **다음에 이야기할 것** (11판 · 이슈 88 · FR-063 · D-78 · 2026-11-06 사용자) — 사람 상세와 만나기 전에 칸(FR-061)이 같이 쓴다.
///
/// - 끝내지 않은 것을 더한 차례대로, 동그라미를 누르면 끝냄(체크) · 다시 누르면 되살림. 끝낸 것은 `끝낸 것 n개` 아래 접어 둔다.
/// - 맨 아래 칸에 적고 줄바꿈(또는 `더하기`)으로 더한다.
/// - 빼기는 줄을 밀어 **역할 없는 단추** → 확인 창(모든 삭제에 확인 · CLAUDE.md). 확인 창은 목록 밖의 화면이 든다 —
///   양식 · 목록 줄 안에 붙인 창은 뜨지 않은 적이 있다(이슈 72). 그래서 지울 줄은 `removing` 으로 화면에 넘긴다.
/// - 저장에 실패하면 `onError` 로 알린다(화면이 알림 창을 든다).
struct TalkItemsSection: View {
    let person: Person
    @Binding var removing: TalkItem?
    var title: String = "다음에 이야기할 것"
    let onError: (String) -> Void

    @Environment(\.modelContext) private var context
    @State private var newText = ""
    @State private var showingDone = false
    @FocusState private var focused: Bool

    private var store: PersonStore { PersonStore(context: context) }

    /// CI 스크린샷이 이 칸까지 내릴 때 (`-scrollToTalk`). 만나기 전에 칸에는 사람마다 있어 사람 열쇠를 붙인다.
    static func anchor(for person: Person) -> String { "talkItems-" + person.uuid.uuidString }

    var body: some View {
        let open = person.openTalkItems
        let done = person.doneTalkItems
        Section {
            ForEach(open) { item in
                row(item)
            }
            addRow
            if !done.isEmpty {
                Button {
                    withAnimation { showingDone.toggle() }
                } label: {
                    Label(showingDone ? "끝낸 것 접기" : "끝낸 것 \(done.count)개", systemImage: showingDone ? "chevron.up" : "chevron.down")
                        .font(.scaled(14))
                        .foregroundStyle(Color.muted)
                }
                .accessibilityIdentifier("talkDoneToggle")
                if showingDone {
                    ForEach(done) { item in
                        row(item)
                    }
                }
            }
        } header: {
            Text(open.isEmpty ? title : "\(title) \(open.count)")
        } footer: {
            if open.isEmpty && done.isEmpty {
                Text("다음에 물어볼 것 · 전할 것을 적어 두면 다가오는 만남에서 다시 보입니다.")
            }
        }
        .id(Self.anchor(for: person))
    }

    private func row(_ item: TalkItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.scaled(20))
                    .foregroundStyle(item.isDone ? Color.accent : Color.faint)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isDone ? "다시 열기" : "끝냄")
            .accessibilityIdentifier("talkToggle")
            Text(item.text)
                .font(.scaled(16))
                .foregroundStyle(item.isDone ? Color.muted : Color.bodyText)
                .strikethrough(item.isDone, color: Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Font.scaledLength(10))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // 역할 없는 단추 — `role: .destructive` 는 확인 전에 줄을 먼저 접는다 (느린 부자 178~182).
            Button {
                removing = item
            } label: {
                Label("빼기", systemImage: "minus.circle")
            }
            .tint(Color.danger)
        }
        .accessibilityIdentifier("talkRow")
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("이야기할 것 더하기", text: $newText)
                .font(.scaled(16))
                .focused($focused)
                .submitLabel(.done)
                .limited($newText, to: Limits.talkItem)
                .onSubmit(add)
                .accessibilityIdentifier("talkField")
            if !TextNormalization.normalized(newText).isEmpty {
                Button("더하기", action: add)
                    .font(.scaled(15, weight: .semibold))
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accent)
            }
        }
    }

    private func add() {
        let text = newText
        guard !TextNormalization.normalized(text).isEmpty else { return }
        do {
            try store.addTalkItem(text, to: person)
            newText = ""
        } catch {
            onError("\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요.")
        }
    }

    private func toggle(_ item: TalkItem) {
        do {
            try store.setTalkItem(item, done: !item.isDone)
        } catch {
            onError("\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요.")
        }
    }
}

/// 다음에 이야기할 것 빼기 확인 창 + 저장 실패 알림 — 이 칸을 쓰는 화면이 목록 밖에 붙인다.
struct TalkItemAlerts: ViewModifier {
    @Binding var removing: TalkItem?
    @Binding var error: String?
    let store: PersonStore

    func body(content: Content) -> some View {
        content
            .confirmationDialog("이 줄을 뺄까요?",
                                isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible, presenting: removing) { item in
                Button("빼기", role: .destructive) {
                    do {
                        try store.removeTalkItem(item)
                    } catch {
                        self.error = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
                    }
                    removing = nil
                }
                Button("취소", role: .cancel) { removing = nil }
            } message: { item in
                Text(item.isGone ? "" : item.text)
            }
            .alert("저장하지 못했습니다", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
    }
}
