import AppIntents
import SwiftUI

/// **단축어** (빌드 16 · 조사 보고서 지금 6) — 사람 추가 · 기록 추가 · 명함 찍기를 앱을 열자마자.
///
/// 앱을 여는 인텐트만 둔다: 인텐트는 요청을 여기에 적고, 사람 목록(`PeopleListView`)이 읽어 시트를 띄운다.
/// 권한이 필요 없고 네트워크를 쓰지 않는다. 단축어 앱 · Siri · Spotlight 에 앱 이름과 함께 나온다.
@MainActor
final class ShortcutRequests: ObservableObject {
    enum Request: Equatable {
        case addPerson
        case addRecord
        case scanCard
    }

    static let shared = ShortcutRequests()

    @Published var pending: Request?

    func ask(_ request: Request) {
        pending = request
    }
}

struct AddPersonIntent: AppIntent {
    static let title: LocalizedStringResource = "사람 추가"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await ShortcutRequests.shared.ask(.addPerson)
        return .result()
    }
}

struct AddRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "기록 추가"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await ShortcutRequests.shared.ask(.addRecord)
        return .result()
    }
}

struct ScanCardIntent: AppIntent {
    static let title: LocalizedStringResource = "명함 찍기"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await ShortcutRequests.shared.ask(.scanCard)
        return .result()
    }
}

struct SlowConnectionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddPersonIntent(),
                    phrases: ["\(.applicationName)에 사람 추가", "\(.applicationName) 사람 추가"],
                    shortTitle: "사람 추가", systemImageName: "person.badge.plus")
        AppShortcut(intent: AddRecordIntent(),
                    phrases: ["\(.applicationName)에 기록 추가", "\(.applicationName) 기록 추가"],
                    shortTitle: "기록 추가", systemImageName: "square.and.pencil")
        AppShortcut(intent: ScanCardIntent(),
                    phrases: ["\(.applicationName)로 명함 찍기", "\(.applicationName) 명함 찍기"],
                    shortTitle: "명함 찍기", systemImageName: "camera.viewfinder")
    }
}
