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
    /// 연락 수단 다섯 칸 (이슈 11). 명함의 `M.` · `T.` · `F.` · `E.` 로 갈라 온다.
    @State private var contact: [ContactFields.Kind: String] = [:]
    @State private var useName = false
    @State private var useOrganization = false
    @State private var useRole = false
    @State private var useContact: Set<ContactFields.Kind> = []

    private struct ContactRow: Identifiable {
        let kind: ContactFields.Kind
        let label: String
        var id: String { kind.rawValue }
    }

    private static let contactRows = [
        ContactRow(kind: .mobile, label: "휴대전화"), ContactRow(kind: .office, label: "사무실 전화"),
        ContactRow(kind: .fax, label: "팩스"), ContactRow(kind: .email, label: "이메일"), ContactRow(kind: .other, label: "기타"),
    ]

    init(suggestion: CardSuggestion, draft: Binding<PersonDraft>) {
        self.suggestion = suggestion
        _draft = draft
        let current = draft.wrappedValue
        _name = State(initialValue: suggestion.name)
        _organization = State(initialValue: suggestion.organization)
        _role = State(initialValue: suggestion.role)
        var contact: [ContactFields.Kind: String] = [:]
        for kind in ContactFields.Kind.allCases where !suggestion.contact[kind].isEmpty {
            contact[kind] = suggestion.contact[kind]
        }
        _contact = State(initialValue: contact)
        // 이미 적어 둔 칸은 덮지 않는 쪽이 기본이다.
        func empty(_ text: String) -> Bool { TextNormalization.normalized(text).isEmpty }
        _useName = State(initialValue: suggestion.name != nil && empty(current.name))
        _useOrganization = State(initialValue: suggestion.organization != nil && empty(current.organization))
        _useRole = State(initialValue: suggestion.role != nil && empty(current.role))
        _useContact = State(initialValue: Set(contact.keys.filter { empty(Self.current(current, $0)) }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    row("이름", value: name, isOn: $useName)
                    row("소속", value: organization, isOn: $useOrganization)
                    row("직무", value: role, isOn: $useRole)
                } header: {
                    Text("넣을 것만 고르세요")
                }
                Section {
                    ForEach(Self.contactRows) { item in
                        // 기타는 읽은 것이 있을 때만 — 대개 비어 있어 줄만 늘린다.
                        if item.kind != .other || contact[.other] != nil {
                            row(item.label, value: contact[item.kind], isOn: contactBinding(item.kind))
                        }
                    }
                } header: {
                    Text("연락 수단")
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
                            Button("휴대전화로") { assign(line, to: .mobile) }
                            Button("사무실 전화로") { assign(line, to: .office) }
                            Button("팩스로") { assign(line, to: .fax) }
                            Button("이메일로") { assign(line, to: .email) }
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
                        .disabled(!(useName || useOrganization || useRole || !useContact.isEmpty))
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

    private func contactBinding(_ kind: ContactFields.Kind) -> Binding<Bool> {
        Binding(
            get: { useContact.contains(kind) },
            set: { on in
                if on { useContact.insert(kind) } else { useContact.remove(kind) }
            }
        )
    }

    /// 줄을 연락 칸으로 — 줄에 번호 · 메일이 있으면 그것만(`M.` 같은 이름표는 떼고), 없으면 줄 그대로.
    private func assign(_ line: String, to kind: ContactFields.Kind) {
        let split = ContactSorter.split(line)
        let candidates = kind == .email ? [split.email] : [split[kind], split.mobile, split.office, split.fax]
        contact[kind] = candidates.first { !$0.isEmpty } ?? line
        useContact.insert(kind)
    }

    private static func current(_ draft: PersonDraft, _ kind: ContactFields.Kind) -> String {
        switch kind {
        case .mobile: return draft.mobilePhone
        case .office: return draft.officePhone
        case .fax: return draft.faxNumber
        case .email: return draft.email
        case .other: return draft.contactNote
        }
    }

    private func apply() {
        if useName, let name { draft.name = String(name.prefix(Limits.name)) }
        if useOrganization, let organization { draft.organization = String(organization.prefix(Limits.organization)) }
        if useRole, let role { draft.role = String(role.prefix(Limits.role)) }
        var fields = ContactFields()
        for kind in useContact {
            guard let value = contact[kind] else { continue }
            switch kind {
            case .mobile: fields.mobile = value
            case .office: fields.office = value
            case .fax: fields.fax = value
            case .email: fields.email = value
            case .other: fields.other = value
            }
        }
        draft.fill(fields)
        dismiss()
    }
}
