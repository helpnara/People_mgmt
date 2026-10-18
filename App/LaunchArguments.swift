import Foundation

/// CI 스크린샷 · 테스트가 실행 인자로 화면을 지정한다 (.github/workflows/ios.yml).
///
/// 원격 세션은 앱을 눌러 볼 수 없다. 켜기만 하면 빈 목록 한 장밖에 못 보므로,
/// 인자로 견본 자료를 채우고 특정 화면을 바로 연다.
struct LaunchArguments: Sendable {
    static let current = LaunchArguments(ProcessInfo.processInfo.arguments)

    /// 인메모리 저장소에 견본 자료를 채운다. **진짜 저장소에는 손대지 않는다.**
    let seedSampleData: Bool
    /// 견본에 사람 5,000명 · 기록 50,000건을 더 채운다 — 화면 시간을 재려고 (요구사항 8.5). `-seedSampleData` 와 함께.
    let largeSample: Bool
    /// 목록의 첫 사람 상세를 바로 연다.
    let openFirstPerson: Bool
    /// 이 이름의 사람 상세를 바로 연다 (`-openPerson 김하늘`). 첫 인연 · 소개 관계가 있는 사람을 찍으려고.
    let openPerson: String?
    /// 사람 추가 시트를 바로 연다.
    let addPerson: Bool
    /// 연 사람의 가장 최근 기록 상세까지 연다.
    let openRecord: Bool
    /// 연 사람의 기록 추가 시트를 바로 연다.
    let addRecord: Bool
    /// 연 사람의 수정 시트를 바로 연다.
    let editPerson: Bool
    /// 수정 시트에서 명함 글자를 바로 읽어 제안 화면을 띄운다.
    let readCard: Bool
    /// 검색창에 이 글자를 넣은 채로 연다.
    let search: String?
    /// 저장소를 일부러 못 열게 한다 — 안내 화면이 뜨는지 본다.
    let simulateStoreFailure: Bool

    init(_ arguments: [String]) {
        seedSampleData = arguments.contains("-seedSampleData")
        largeSample = arguments.contains("-seedLargeSample")
        openFirstPerson = arguments.contains("-openFirstPerson")
        addPerson = arguments.contains("-addPerson")
        openRecord = arguments.contains("-openRecord")
        addRecord = arguments.contains("-addRecord")
        editPerson = arguments.contains("-editPerson")
        readCard = arguments.contains("-readCard")
        simulateStoreFailure = arguments.contains("-simulateStoreFailure")
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        search = value(after: "-search")
        openPerson = value(after: "-openPerson")
    }
}
