import Foundation

/// 입력 길이 제한 (요구사항 7.2). 화면은 이 수를 넘는 입력을 막고, 저장소는 믿지 않고 다시 자른다.
public enum Limits {
    public static let name = 100
    public static let nickname = 100
    public static let organization = 100
    public static let role = 100
    public static let relationshipType = 50
    public static let metThrough = 100
    public static let firstNote = 5_000
    public static let contactNote = 500
    public static let recordTitle = 100
    public static let recordNote = 20_000
    public static let location = 100
}

public enum PersonValidation {
    /// 이름이 저장 가능한가. 아니면 **사용자에게 보여 줄 문장**을 돌려준다.
    public static func nameProblem(_ name: String) -> String? {
        let cleaned = TextNormalization.normalized(name)
        if cleaned.isEmpty { return "이름을 입력하세요" }
        if cleaned.count > Limits.name { return "이름은 \(Limits.name)자까지 쓸 수 있습니다" }
        return nil
    }
}

public enum RecordValidation {
    /// 제목 또는 메모 중 하나는 공백을 빼고 1자 이상이어야 한다 (D-4).
    public static func canSave(title: String?, note: String?) -> Bool {
        let hasTitle = !(TextNormalization.nilIfEmpty(title) == nil)
        let hasNote = !(TextNormalization.nilIfEmpty(note) == nil)
        return hasTitle || hasNote
    }
}
