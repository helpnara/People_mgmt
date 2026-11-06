import Foundation

/// **앱과 확장이 함께 보는 작은 파일** (1.1.9 · 빌드 63 · D-79) — 위젯(이슈 100 · FR-075) · 공유 시트(이슈 101 · FR-076).
///
/// 저장소(SwiftData)는 앱만 연다. 확장은 App Group 그릇의 파일만 읽고 쓴다 — 위젯은 앱이 남긴 요약을 읽고,
/// 공유 시트는 초안 파일을 남겨 앱이 다음에 열릴 때 기록으로 잇는다. 셈은 앱이 하고 확장은 그리기만 한다.
public enum SharedFiles {
    /// App Group — 앱 · 위젯 · 공유 시트의 권한 파일(entitlements)에 같은 이름이 들어 있다 (project.yml).
    public static let appGroup = "group.com.helpnara.slow.connection"
    /// 위젯 요약 파일 이름.
    public static let widgetSummary = "widget-summary.json"
    /// 공유 초안 폴더 — 초안 하나가 폴더 하나(`draft.json` + 사진 `photo-0.jpg` …).
    public static let shareDrafts = "ShareDrafts"
    public static let draftFile = "draft.json"
    /// 초안에 담는 사진 수 — 기록 사진 한도(4)와 같다.
    public static let draftPhotoLimit = 4
}

/// 위젯이 그리는 요약 (FR-075). 날은 `CivilDate.dayNumber`(1970 기준) — 위젯이 오늘과 견줘 `오늘` · `내일` · `3일 후` 로 쓴다.
public struct WidgetSummary: Codable, Sendable, Equatable {
    /// 이름을 보이나 · 숨기나 · 건수만인가 (D-79 — 이름 보임, 설정에서 숨김, 앱 잠금이면 건수만).
    public enum Mode: String, Codable, Sendable {
        case names
        case hidden
        case countsOnly
    }

    public struct Item: Codable, Sendable, Equatable {
        public enum Kind: String, Codable, Sendable {
            case meeting
            case birthday
            case special
        }

        public let kind: Kind
        public let day: Int
        /// 약속 시각(자정부터 분). 생일 · 기념일은 nil.
        public let minute: Int?
        /// 약속 제목 · `생일` · `결혼기념일 8주년`. 이름을 숨기면 nil.
        public let title: String?
        /// 함께할 사람 · 그날의 사람. 이름을 숨기면 nil.
        public let names: String?

        public init(kind: Kind, day: Int, minute: Int?, title: String?, names: String?) {
            self.kind = kind
            self.day = day
            self.minute = minute
            self.title = title
            self.names = names
        }
    }

    public var mode: Mode
    public var madeAt: Date
    /// 오늘부터 14일 안의 약속 — 날 · 시각 차례. 건수만이면 비운다.
    public var meetings: [Item]
    public var meetingCount: Int
    /// 오늘부터 7일 안의 생일 · 기념일. 건수만이면 비운다.
    public var days: [Item]
    public var dayCount: Int

    public init(mode: Mode, madeAt: Date, meetings: [Item], meetingCount: Int, days: [Item], dayCount: Int) {
        self.mode = mode
        self.madeAt = madeAt
        self.meetings = meetings
        self.meetingCount = meetingCount
        self.days = days
        self.dayCount = dayCount
    }

    /// 위젯이 보는 날 수.
    public static let meetingWindow = 14
    public static let dayWindow = 7
    /// 파일에 담는 줄 수 — 가장 큰 위젯이 그리는 만큼.
    public static let itemLimit = 6
}

/// 공유 시트가 남긴 초안 (FR-076) — 다른 앱의 글 · 주소 · 사진. 앱이 열리면 누구와의 기록인지 골라 기록 추가로 잇는다.
public struct SharedDraft: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    /// 글 · 주소를 합친 메모 — 그대로 기록 메모에 들어간다.
    public var text: String
    /// 같은 폴더의 사진 파일 이름 (`photo-0.jpg` …).
    public var photoFiles: [String]

    public init(id: UUID = UUID(), createdAt: Date = Date(), text: String, photoFiles: [String]) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.photoFiles = photoFiles
    }

    /// 목록 한 줄 — 메모의 첫 줄, 없으면 사진 수.
    public var headline: String {
        let first = text.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if !first.isEmpty { return first }
        return photoFiles.isEmpty ? "빈 초안" : "사진 \(photoFiles.count)장"
    }

    /// 글과 주소를 메모 하나로 — 빈 것은 빼고 줄을 바꿔 잇는다. 메모 한도로 자른다.
    public static func joinedText(_ parts: [String], limit: Int) -> String {
        let cleaned = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var seen = Set<String>()
        let unique = cleaned.filter { seen.insert($0).inserted }
        return String(unique.joined(separator: "\n").prefix(limit))
    }
}
