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
    /// 견본에 모임 셋(15명 · 아는 사이)을 더 채운다 — 모임 찾기를 찍으려고 (D-30). `-seedSampleData` 와 함께.
    let communitySample: Bool
    /// 목록의 첫 사람 상세를 바로 연다.
    let openFirstPerson: Bool
    /// 이 이름의 사람 상세를 바로 연다 (`-openPerson 김하늘`). 첫 인연 · 소개 관계가 있는 사람을 찍으려고.
    let openPerson: String?
    /// 사람 추가 시트를 바로 연다.
    let addPerson: Bool
    /// 나(이슈 12)의 상세를 바로 연다.
    let openMe: Bool
    /// 연 사람의 가장 최근 기록 상세까지 연다.
    let openRecord: Bool
    /// 연 사람의 기록 추가 시트를 바로 연다.
    let addRecord: Bool
    /// 연 사람의 수정 시트를 바로 연다.
    let editPerson: Bool
    /// 연 사람의 명함 크게 보기를 바로 연다 (이슈 14).
    let viewCard: Bool
    /// 연 사람 상세를 관계 돌아보기 구역까지 내린다 (6번째 묶음).
    let scrollToReview: Bool
    /// 내 인맥을 이 보기로 바로 연다 (`-openNetwork graph|traits|overview|readiness`).
    let openNetwork: String?
    /// 수정 시트에서 명함 글자를 바로 읽어 제안 화면을 띄운다.
    let readCard: Bool
    /// 사람 추가 · 수정 시트에서 사진첩 고르기 창을 바로 띄운다 — 그 길에서 앱이 멈추지 않는지 CI 가 본다 (이슈 10).
    let pickCardPhoto: Bool
    /// 검색창에 이 글자를 넣은 채로 연다.
    let search: String?
    /// 저장소를 일부러 못 열게 한다 — 안내 화면이 뜨는지 본다.
    let simulateStoreFailure: Bool
    /// 저장을 일부러 실패시킨다 — 저장 실패 알림 · 입력 유지 · 다시 시도를 본다 (AC-29 · 전수조사 이슈 19).
    /// `-simulateStoreFailure` 는 저장소 **열기** 실패, 이것은 **저장** 실패.
    let failSaves: Bool
    /// 관계도의 시점 막대를 이 자리로 (`-timeSlice 2` — 0 이 가장 이른 분기). 지난 시점의 관계도를 찍으려고 (D-32).
    let timeSlice: Int?
    /// 설정 화면을 바로 연다 (`-openSettings`) — 백업 · 복원 화면을 찍으려고 (D-34).
    let openSettings: Bool
    /// 아는 사이 후보 화면을 바로 연다 (`-openSuggestions` · 빌드 16).
    let openSuggestions: Bool
    /// 채울 것 목록 `처음 만난 날이 빈 사람` 을 바로 연다 (`-openFillFirstMet` · 이슈 28 — 줄 구분선을 스크린샷으로 본다).
    let openFillFirstMet: Bool
    /// 설정의 태그 관리를 바로 연다 (`-openSettings -openTags` · 빌드 27).
    let openTags: Bool
    /// 앱 잠금 가리개를 확인 없이 띄운다 (`-previewLock` · 빌드 27) — 가리개 모양만 찍는다.
    let previewLock: Bool
    /// 기록 추가 · 수정의 태그 칸에 이 글자를 넣고 그 자리까지 내린다 (`-tagInput ㅁㅌ` · 이슈 34 — 자동완성 칩을 찍으려고).
    let tagInput: String?
    /// 사람 목록을 이 태그로 거른 채 연다 (`-filterTag 멘토` · 빌드 27).
    let filterTag: String?
    /// 스토어 스크린샷 (`-storeShots` · 빌드 18) — 견본 안내 띠를 숨긴다. 사람은 여전히 모두 지어낸 견본이다.
    let storeShots: Bool
    /// 큰 견본에서 사람 한 명 · 기록 한 건을 저장해 시간을 잰다 (`-measureSave` · 요구사항 8.5 저장 0.3초).
    let measureSave: Bool
    /// 견본 둘러보기를 바로 연다 (`-startDemo` · D-55 · CI 스크린샷).
    let startDemo: Bool

    init(_ arguments: [String]) {
        seedSampleData = arguments.contains("-seedSampleData")
        largeSample = arguments.contains("-seedLargeSample")
        communitySample = arguments.contains("-seedCommunitySample")
        openFirstPerson = arguments.contains("-openFirstPerson")
        addPerson = arguments.contains("-addPerson")
        openMe = arguments.contains("-openMe")
        openRecord = arguments.contains("-openRecord")
        addRecord = arguments.contains("-addRecord")
        editPerson = arguments.contains("-editPerson")
        viewCard = arguments.contains("-viewCard")
        scrollToReview = arguments.contains("-scrollToReview")
        readCard = arguments.contains("-readCard")
        pickCardPhoto = arguments.contains("-pickCardPhoto")
        simulateStoreFailure = arguments.contains("-simulateStoreFailure")
        failSaves = arguments.contains("-failSaves")
        openSettings = arguments.contains("-openSettings")
        openSuggestions = arguments.contains("-openSuggestions")
        openFillFirstMet = arguments.contains("-openFillFirstMet")
        storeShots = arguments.contains("-storeShots")
        openTags = arguments.contains("-openTags")
        previewLock = arguments.contains("-previewLock")
        measureSave = arguments.contains("-measureSave")
        startDemo = arguments.contains("-startDemo")
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        search = value(after: "-search")
        openPerson = value(after: "-openPerson")
        openNetwork = value(after: "-openNetwork")
        timeSlice = value(after: "-timeSlice").flatMap { Int($0) }
        filterTag = value(after: "-filterTag")
        tagInput = value(after: "-tagInput")
    }
}
