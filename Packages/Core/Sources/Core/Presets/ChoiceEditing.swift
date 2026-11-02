import Foundation

/// 고칠 수 있는 선택지의 종류 (FR-035 · 9판 · 2026-11-03 사용자) — 관계 유형 · 알게 된 경로. 기록 유형은 그림과 묶여 있어 그대로다.
public enum ChoiceKind: String, CaseIterable, Sendable {
    case relationshipType
    case metThrough

    /// 화면 이름.
    public var title: String {
        switch self {
        case .relationshipType: return "관계 유형"
        case .metThrough: return "알게 된 경로"
        }
    }

    /// 앱이 처음 주는 선택지.
    public var presets: [String] {
        switch self {
        case .relationshipType: return RelationshipPresets.relationshipTypes
        case .metThrough: return RelationshipPresets.metThroughOptions
        }
    }

    /// 숨길 수 없는 선택지 — 알게 된 경로의 `소개`(이걸 골라야 소개한 사람 칸이 나온다 · FR-043).
    public var fixed: [String] {
        switch self {
        case .relationshipType: return []
        case .metThrough: return [RelationshipPresets.introducedLabel]
        }
    }
}

/// 내가 정한 선택지 — 보이는 것(차례대로)과 숨긴 것. 저장하지 않았으면 nil(기본값 그대로).
public struct ChoiceSetting: Sendable, Equatable {
    public var items: [String]
    public var hidden: [String]

    public init(items: [String], hidden: [String]) {
        self.items = items
        self.hidden = hidden
    }
}

/// **선택지 내 맘대로** (FR-035 · 9판) — 기본값 · 내가 정한 차례 · 숨긴 것 · 사람들에게 직접 입력해 쓴 값을 한 목록으로.
///
/// - 정한 것이 없으면 기본값 그대로(그 뒤에 직접 입력해 쓴 값 — 이슈 13 · `RelationshipPresets.choices`).
/// - 정한 것이 있으면 그 차례대로. 빈 값 · 겹침은 뺀다. 숨긴 것은 보이지 않는다 — 사람에게 쓰인 값이어도.
/// - 정한 뒤에 앱이 새로 더한 기본값(보이지도 숨기지도 않은 것)과 숨길 수 없는 것(`소개`)은 끝에 붙는다.
/// - 직접 입력해 쓴 값 중 보이지도 숨기지도 않은 것은 그 뒤에 — 많이 쓴 것부터(이슈 13 과 같은 차례).
///
/// 같은 것을 정리하는 곳은 하나다: 글자는 `TextNormalization.normalized`, 차례 열쇠는 `NameSort.key`.
/// 파이썬 정답표(`Tools/golden` 의 `choiceEditing`)와 같은 셈이다.
public enum ChoiceEditing {
    /// 숨긴 것 — 정리 · 겹침 빼기 · 숨길 수 없는 것 빼기, 저장한 차례대로.
    public static func hidden(fixed: [String], setting: ChoiceSetting?) -> [String] {
        guard let setting else { return [] }
        var out: [String] = []
        for raw in setting.hidden {
            let value = TextNormalization.normalized(raw)
            guard !value.isEmpty, !fixed.contains(value), !out.contains(value) else { continue }
            out.append(value)
        }
        return out
    }

    /// 보이는 선택지(직접 입력해 쓴 값은 빼고).
    public static func visible(presets: [String], fixed: [String], setting: ChoiceSetting?) -> [String] {
        guard let setting else { return presets + fixed.filter { !presets.contains($0) } }
        let hiddenValues = hidden(fixed: fixed, setting: setting)
        var out: [String] = []
        for raw in setting.items {
            let value = TextNormalization.normalized(raw)
            guard !value.isEmpty, !out.contains(value), !hiddenValues.contains(value) else { continue }
            out.append(value)
        }
        for value in presets + fixed where !out.contains(value) && !hiddenValues.contains(value) {
            out.append(value)
        }
        return out
    }

    /// 칩으로 보일 선택지 — 보이는 것 + 직접 입력해 쓴 값(보이지도 숨기지도 않은 것, 많이 쓴 것부터).
    /// 화면 본문이 아니라 화면을 열 때 한 번 부른다.
    public static func choices(presets: [String], fixed: [String], setting: ChoiceSetting?, used: [String]) -> [String] {
        let shown = visible(presets: presets, fixed: fixed, setting: setting)
        let hiddenValues = hidden(fixed: fixed, setting: setting)
        let extras = RelationshipPresets.choices(presets: shown, used: used).dropFirst(shown.count)
        return shown + extras.filter { !hiddenValues.contains($0) }
    }

    public static func choices(_ kind: ChoiceKind, setting: ChoiceSetting?, used: [String]) -> [String] {
        choices(presets: kind.presets, fixed: kind.fixed, setting: setting, used: used)
    }

    /// 선택지 하나를 더한다 — 정리한 글자가 비었거나 이미 보이면 그대로. 숨겨 둔 것이면 다시 보이게.
    public static func adding(_ raw: String, to items: [String], hidden: [String]) -> (items: [String], hidden: [String]) {
        let value = TextNormalization.normalized(raw)
        guard !value.isEmpty, !items.contains(value) else { return (items, hidden) }
        return (items + [value], hidden.filter { $0 != value })
    }

    /// 선택지 하나를 숨긴다 — 숨길 수 없는 것은 그대로.
    public static func hiding(_ value: String, in items: [String], hidden: [String], fixed: [String]) -> (items: [String], hidden: [String]) {
        guard !fixed.contains(value), items.contains(value) else { return (items, hidden) }
        return (items.filter { $0 != value }, hidden.contains(value) ? hidden : hidden + [value])
    }

    /// 숨긴 것을 다시 보이게 — 보이는 목록 끝에.
    public static func showing(_ value: String, in items: [String], hidden: [String]) -> (items: [String], hidden: [String]) {
        guard hidden.contains(value) else { return (items, hidden) }
        return (items.contains(value) ? items : items + [value], hidden.filter { $0 != value })
    }
}
