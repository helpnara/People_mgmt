import Core
import SwiftUI

/// 명함에서 읽은 글자 — 시트로 띄우려고 이름을 붙인다.
struct CardReadingResult: Identifiable {
    let id = UUID()
    let suggestion: CardSuggestion
}

/// 명함에서 읽은 내용을 **제안**으로 보여 주고, 넣을 것만 고르게 한다 (FR-050).
/// 앱이 골라 넣지 않는다 — 글자 인식은 틀릴 수 있고, 틀린 이름이 저장되면 찾기 어렵다.
struct CardSuggestionView: View {
    let suggestion: CardSuggestion
    @Binding var draft: PersonDraft

    @Environment(\.dismiss) private var dismiss
    @State private var name: String?
    @State private var organization: String?
    @State private var role: String?
    @State private var contact: String?
    @State private var useName = false
    @State private var useOrganization = false
    @State private var useRole = false
    @State private var useContact = false

    init(suggestion: CardSuggestion, draft: Binding<PersonDraft>) {
        self.suggestion = suggestion
        _draft = draft
        let current = draft.wrappedValue
        let contactText = ContactNote.compose(phones: suggestion.phones, emails: suggestion.emails)
        _name = State(initialValue: suggestion.name)
        _organization = State(initialValue: suggestion.organization)
        _role = State(initialValue: suggestion.role)
        _contact = State(initialValue: contactText.isEmpty ? nil : contactText)
        // 이미 적어 둔 칸은 덮지 않는 쪽이 기본이다.
        func empty(_ text: String) -> Bool { TextNormalization.normalized(text).isEmpty }
        _useName = State(initialValue: suggestion.name != nil && empty(current.name))
        _useOrganization = State(initialValue: suggestion.organization != nil && empty(current.organization))
        _useRole = State(initialValue: suggestion.role != nil && empty(current.role))
        _useContact = State(initialValue: !contactText.isEmpty && empty(current.contactNote))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    row("이름", value: name, isOn: $useName)
                    row("소속", value: organization, isOn: $useOrganization)
                    row("직무", value: role, isOn: $useRole)
                    row("연락 수단", value: contact, isOn: $useContact)
                } header: {
                    Text("넣을 것만 고르세요")
                } footer: {
                    Text("글자는 기기 안에서만 읽었습니다. 틀린 곳은 아래 줄을 눌러 바로잡을 수 있습니다.")
                }
                Section {
                    if suggestion.lines.isEmpty {
                        Text("읽은 글자가 없습니다. 밝은 곳에서 명함이 화면을 채우게 다시 찍어 보세요.")
                            .font(.scaled(15))
                            .foregroundStyle(Color.muted)
                    }
                    ForEach(Array(suggestion.lines.enumerated()), id: \.offset) { _, line in
                        Menu {
                            Button("이름으로") { name = line; useName = true }
                            Button("소속으로") { organization = line; useOrganization = true }
                            Button("직무로") { role = line; useRole = true }
                            Button("연락 수단으로") { contact = line; useContact = true }
                        } label: {
                            HStack {
                                Text(line).font(.scaled(15)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "ellipsis.circle").foregroundStyle(Color.faint)
                            }
                        }
                    }
                } header: {
                    Text("읽은 글자 \(suggestion.lines.count)줄")
                }
            }
            .navigationTitle("명함에서 읽은 내용")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("넣지 않음") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("채우기", action: apply)
                        .disabled(!(useName || useOrganization || useRole || useContact))
                }
            }
        }
    }

    private func row(_ label: String, value: String?, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.scaled(13)).foregroundStyle(Color.muted)
                Text(value ?? "읽지 못함")
                    .font(.scaled(16, weight: value == nil ? .regular : .medium))
                    .foregroundStyle(value == nil ? Color.faint : Color.ink)
            }
        }
        .disabled(value == nil)
        .tint(Color.accent)
    }

    private func apply() {
        if useName, let name { draft.name = String(name.prefix(Limits.name)) }
        if useOrganization, let organization { draft.organization = String(organization.prefix(Limits.organization)) }
        if useRole, let role { draft.role = String(role.prefix(Limits.role)) }
        if useContact, let contact { draft.contactNote = String(contact.prefix(Limits.contactNote)) }
        dismiss()
    }
}
