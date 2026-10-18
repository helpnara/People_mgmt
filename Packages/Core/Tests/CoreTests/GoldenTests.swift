import Foundation
import XCTest
@testable import Core

/// 파이썬이 **독립 계산**한 기댓값과 Core 의 결과를 견준다.
///
/// 원격 세션에는 Swift 툴체인이 없다. 컴파일 못 하는 환경에서 기댓값을 손으로 적으면
/// 테스트가 버그를 승인한다. 그래서 `Tools/golden/generate.py` 가 설계서만 보고 다시
/// 구현한 값만 쓴다. 기댓값을 고치려면 그 스크립트를 돌리고 결과를 커밋한다.
final class GoldenTests: XCTestCase {

    struct Golden: Decodable {
        struct TagCase: Decodable { let name: String; let input: [String]; let expected: [String] }
        struct SplitCase: Decodable { let name: String; let input: String; let expected: [String] }
        struct TitleCase: Decodable { let name: String; let title: String?; let note: String?; let expected: String }
        struct SortPerson: Decodable { let name: String; let createdAt: Double }
        struct SortCase: Decodable { let name: String; let people: [SortPerson]; let expected: [String] }
        struct DayCase: Decodable { let from: String; let to: String; let expected: String }
        struct ContactNameCase: Decodable { let given: String; let family: String; let expected: String }
        struct ContactNoteCase: Decodable { let phones: [String]; let emails: [String]; let expected: String }
        struct FieldsExpected: Decodable {
            let mobile: String; let office: String; let fax: String; let email: String; let other: String
            var fields: ContactFields { ContactFields(mobile: mobile, office: office, fax: fax, email: email, other: other) }
        }
        struct MetricRecordRaw: Decodable { let id: UUID; let day: Int; let type: String }
        struct TypeCountRaw: Decodable { let type: String; let count: Int }
        struct DyadExpected: Decodable {
            let total: Int; let lastYear: Int; let daysSinceLast: Int?; let spanDays: Int?; let spanFromFirstMeeting: Bool
            let perMonthTenths: Int?; let frequencyText: String?; let trend: String?; let recentHalf: Int; let previousHalf: Int
            let diversityClass: String?; let typeCounts: [TypeCountRaw]; let pastIDs: [UUID]; let lastYearIDs: [UUID]
            let recentHalfIDs: [UUID]; let previousHalfIDs: [UUID]; let firstID: UUID?; let lastID: UUID?; let spanText: String?
        }
        struct DyadCase: Decodable { let name: String; let records: [MetricRecordRaw]; let firstMetDay: Int?; let today: Int; let expected: DyadExpected }
        struct SpanCase: Decodable { let days: Int; let expected: String }
        struct OverviewPersonRaw: Decodable { let id: UUID; let name: String; let firstMetDay: Int?; let lastDay: Int? }
        struct OverviewExpected: Decodable {
            let total: Int; let activeCount: Int; let newThisYearIDs: [UUID]; let quietIDs: [UUID]; let noRecordIDs: [UUID]
        }
        struct OverviewCase: Decodable {
            let name: String; let people: [OverviewPersonRaw]; let today: Int; let yearStart: Int; let yearEnd: Int
            let neglectDays: Int; let expected: OverviewExpected
        }
        struct TraitItemRaw: Decodable { let id: UUID; let values: [String] }
        struct TraitExpected: Decodable { let label: String; let count: Int; let ids: [UUID]; let isUnspecified: Bool; let isRest: Bool }
        struct TraitCase: Decodable { let name: String; let items: [TraitItemRaw]; let limit: Int; let expected: [TraitExpected] }
        struct GraphPersonRaw: Decodable { let id: UUID; let name: String; let organization: String?; let introducedBy: UUID? }
        struct GraphEdgeRaw: Decodable { let a: UUID; let b: UUID; let together: Int; let introduced: Bool; let sameOrganization: Bool; let acquainted: Bool }
        struct GraphCase: Decodable {
            let name: String; let people: [GraphPersonRaw]; let records: [[UUID]]; let ties: [[UUID]]; let cliqueLimit: Int; let expected: [GraphEdgeRaw]
        }
        struct LinkRaw: Decodable { let i: Int; let j: Int; let weight: Double }
        struct LouvainExpected: Decodable { let communities: [[Int]]; let modularity: Double }
        struct LouvainCase: Decodable { let name: String; let nodeCount: Int; let links: [LinkRaw]; let resolution: Double; let expected: LouvainExpected }
        struct SplitCase: Decodable { let name: String; let nodeCount: Int; let links: [LinkRaw]; let communities: [[Int]]; let expected: [[Int]] }
        struct NamingMemberRaw: Decodable { let organization: String?; let tags: [String]?; let metThrough: String? }
        struct NamingCase: Decodable { let name: String; let members: [NamingMemberRaw]; let expected: String? }
        struct ReadinessInputRaw: Decodable {
            let people: Int; let withFirstMet: Int; let withRelationshipType: Int; let withMetThrough: Int
            let withRecords: Int; let strongEdges: Int; let linkedPeople: Int
        }
        struct ReadinessItemRaw: Decodable { let feature: String; let level: String; let progress: Double; let current: String; let hint: String }
        struct ReadinessCase: Decodable { let name: String; let input: ReadinessInputRaw; let expected: [ReadinessItemRaw]; let summary: String }
        struct PresetChoicesCase: Decodable { let name: String; let presets: [String]; let used: [String]; let expected: [String] }
        struct ContactSplitCase: Decodable { let text: String; let expected: FieldsExpected }
        struct LabeledRaw: Decodable { let label: String; let value: String }
        struct ContactFromContactCase: Decodable { let phones: [LabeledRaw]; let emails: [String]; let expected: FieldsExpected }
        struct CardExpected: Decodable {
            let name: String?; let organization: String?; let role: String?
            let phones: [String]; let emails: [String]; let lines: [String]
            let contact: FieldsExpected
        }
        struct CardLineRaw: Decodable {
            let text: String; let height: Double
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                text = try container.decode(String.self)
                height = try container.decode(Double.self)
            }
        }
        struct CardCase: Decodable { let name: String; let lines: [CardLineRaw]; let expected: CardExpected }
        struct RecencyPerson: Decodable { let name: String; let createdAt: Double; let lastRecordAt: Double? }
        struct RecencyCase: Decodable { let name: String; let people: [RecencyPerson]; let expected: [String] }
        struct TimelineRecord: Decodable { let id: String; let occurredAt: Double; let createdAt: Double }
        struct TimelineCase: Decodable { let name: String; let records: [TimelineRecord]; let expected: [String] }
        struct ValidationCase: Decodable { let name: String; let expected: String? }
        struct RecordSaveCase: Decodable { let title: String?; let note: String?; let expected: Bool }
        struct NoonCase: Decodable { let iso: String; let timeZone: String; let expectedEpoch: Double }
        struct Record: Decodable {
            let id: UUID; let displayTitle: String; let title: String?; let note: String?
            let location: String?; let tags: [String]
        }
        struct Person: Decodable {
            let id: UUID; let name: String; let nickname: String?; let organization: String?
            let role: String?; let relationshipType: String?; let metThrough: String?
            let firstNote: String?; let tags: [String]; let records: [Record]
        }
        struct Hit: Decodable { let personID: UUID; let kind: String; let evidence: String; let recordID: UUID? }
        struct Query: Decodable { let query: String; let expected: [Hit] }
        struct Search: Decodable { let people: [Person]; let queries: [Query] }
        struct JosaExpected: Decodable { let eulReul: String; let gwaWa: String; let iGa: String }
        struct JosaCase: Decodable { let text: String; let expected: JosaExpected }

        let tags: [TagCase]
        let tagSplit: [SplitCase]
        let displayTitle: [TitleCase]
        let nameSort: [SortCase]
        let recencySort: [RecencyCase]
        let relativeDay: [DayCase]
        let contactName: [ContactNameCase]
        let contactNote: [ContactNoteCase]
        let contactSplit: [ContactSplitCase]
        let contactFromContact: [ContactFromContactCase]
        let presetChoices: [PresetChoicesCase]
        let louvain: [LouvainCase]
        let splitConnected: [SplitCase]
        let communityName: [NamingCase]
        let inputReadiness: [ReadinessCase]
        let dyadMetrics: [DyadCase]
        let spanText: [SpanCase]
        let networkOverview: [OverviewCase]
        let traitBuckets: [TraitCase]
        let graphEdges: [GraphCase]
        let cardParse: [CardCase]
        let timelineSort: [TimelineCase]
        let validation: [ValidationCase]
        let recordSave: [RecordSaveCase]
        let dayNoon: [NoonCase]
        let search: Search
        let josa: [JosaCase]
    }

    /// `Bundle.module` 대신 소스 위치에서 직접 읽는다 — 리눅스에서 더 단순하고 확실하다.
    static func loadGolden() throws -> Golden {
        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = here.appendingPathComponent("Golden/expected.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Golden.self, from: data)
    }

    func testGoldenFileIsPresent() throws {
        let golden = try Self.loadGolden()
        XCTAssertGreaterThanOrEqual(golden.search.queries.count, 10,
                                    "기댓값 사례가 너무 적습니다. Tools/golden/generate.py 를 돌렸나요?")
    }

    func testTagNormalization() throws {
        for c in try Self.loadGolden().tags {
            XCTAssertEqual(TagNormalizer.normalizeList(c.input), c.expected, c.name)
        }
    }

    func testTagSplit() throws {
        for c in try Self.loadGolden().tagSplit {
            XCTAssertEqual(TagNormalizer.parse(c.input), c.expected, c.name)
        }
    }

    func testDisplayTitle() throws {
        for c in try Self.loadGolden().displayTitle {
            XCTAssertEqual(DisplayTitle.make(title: c.title, note: c.note), c.expected, c.name)
        }
    }

    func testNameSort() throws {
        for c in try Self.loadGolden().nameSort {
            let people = c.people.map { (name: $0.name, createdAt: Date(timeIntervalSince1970: $0.createdAt)) }
            let sorted = people.sorted(by: NameSort.areInIncreasingOrder).map(\.name)
            XCTAssertEqual(sorted, c.expected, c.name)
        }
    }

    func testRecencySortHelperMatchesComparator() throws {
        for c in try Self.loadGolden().recencySort {
            let sorted = RecencySort.sorted(c.people,
                                            lastRecordAt: { $0.lastRecordAt.map { Date(timeIntervalSince1970: $0) } },
                                            name: { $0.name },
                                            createdAt: { Date(timeIntervalSince1970: $0.createdAt) }).map(\.name)
            XCTAssertEqual(sorted, c.expected, c.name)
        }
    }

    func testNameSortHelperMatchesComparator() throws {
        for c in try Self.loadGolden().nameSort {
            let sorted = NameSort.sorted(c.people, name: { $0.name }, createdAt: { Date(timeIntervalSince1970: $0.createdAt) }).map(\.name)
            XCTAssertEqual(sorted, c.expected, c.name)
        }
    }

    func testRelativeDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        func noon(_ iso: String) throws -> Date {
            let parts = iso.split(separator: "-").compactMap { Int($0) }
            return try XCTUnwrap(calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)), iso)
        }
        for c in try Self.loadGolden().relativeDay {
            XCTAssertEqual(RelativeDay.phrase(from: try noon(c.from), to: try noon(c.to), calendar: calendar), c.expected, "\(c.from) → \(c.to)")
        }
    }

    func testContactName() throws {
        for c in try Self.loadGolden().contactName {
            XCTAssertEqual(ContactName.compose(given: c.given, family: c.family), c.expected, "\(c.given) / \(c.family)")
        }
    }

    func testContactNote() throws {
        for c in try Self.loadGolden().contactNote {
            XCTAssertEqual(ContactNote.compose(phones: c.phones, emails: c.emails), c.expected)
        }
    }

    func testBusinessCardParser() throws {
        for c in try Self.loadGolden().cardParse {
            let got = BusinessCardParser.parse(c.lines.map { CardLine(text: $0.text, height: $0.height) })
            XCTAssertEqual(got.name, c.expected.name, "\(c.name) — 이름")
            XCTAssertEqual(got.organization, c.expected.organization, "\(c.name) — 소속")
            XCTAssertEqual(got.role, c.expected.role, "\(c.name) — 직무")
            XCTAssertEqual(got.phones, c.expected.phones, "\(c.name) — 전화")
            XCTAssertEqual(got.emails, c.expected.emails, "\(c.name) — 메일")
            XCTAssertEqual(got.lines, c.expected.lines, "\(c.name) — 줄")
            XCTAssertEqual(got.contact, c.expected.contact.fields, "\(c.name) — 연락 수단 칸")
        }
    }

    func testDyadMetrics() throws {
        for c in try Self.loadGolden().dyadMetrics {
            let records = c.records.map { MetricRecord(id: $0.id, day: $0.day, type: $0.type) }
            let got = DyadMetricsCalculator.compute(records: records, firstMetDay: c.firstMetDay, today: c.today)
            let e = c.expected
            XCTAssertEqual(got.total, e.total, "\(c.name) — 건수")
            XCTAssertEqual(got.lastYear, e.lastYear, "\(c.name) — 12개월")
            XCTAssertEqual(got.daysSinceLast, e.daysSinceLast, "\(c.name) — 마지막 기록")
            XCTAssertEqual(got.spanDays, e.spanDays, "\(c.name) — 인연 기간")
            XCTAssertEqual(got.spanDays.map(MetricText.span(days:)), e.spanText, "\(c.name) — 인연 기간 글")
            XCTAssertEqual(got.spanFromFirstMeeting, e.spanFromFirstMeeting, c.name)
            XCTAssertEqual(got.perMonth.map { Int(($0 * 10).rounded(.toNearestOrAwayFromZero)) }, e.perMonthTenths, "\(c.name) — 빈도")
            XCTAssertEqual(got.perMonth.map(MetricText.frequency(perMonth:)), e.frequencyText, "\(c.name) — 빈도 글")
            XCTAssertEqual(got.trend?.rawValue, e.trend, "\(c.name) — 추세")
            XCTAssertEqual(got.recentHalf, e.recentHalf, c.name)
            XCTAssertEqual(got.previousHalf, e.previousHalf, c.name)
            XCTAssertEqual(got.diversityClass?.rawValue, e.diversityClass, "\(c.name) — 다양성")
            XCTAssertEqual(got.typeCounts.map(\.type), e.typeCounts.map(\.type), "\(c.name) — 유형")
            XCTAssertEqual(got.typeCounts.map(\.count), e.typeCounts.map(\.count), "\(c.name) — 유형 건수")
            XCTAssertEqual(got.pastIDs, e.pastIDs, "\(c.name) — 근거")
            XCTAssertEqual(got.lastYearIDs, e.lastYearIDs, c.name)
            XCTAssertEqual(got.recentHalfIDs, e.recentHalfIDs, c.name)
            XCTAssertEqual(got.previousHalfIDs, e.previousHalfIDs, c.name)
            XCTAssertEqual(got.firstID, e.firstID, c.name)
            XCTAssertEqual(got.lastID, e.lastID, c.name)
        }
    }

    func testSpanText() throws {
        for c in try Self.loadGolden().spanText {
            XCTAssertEqual(MetricText.span(days: c.days), c.expected, "\(c.days)일")
        }
    }

    func testNetworkOverview() throws {
        for c in try Self.loadGolden().networkOverview {
            let people = c.people.map { OverviewPerson(id: $0.id, name: $0.name, firstMetDay: $0.firstMetDay, lastDay: $0.lastDay) }
            let got = NetworkOverview.compute(people: people, today: c.today, yearStart: c.yearStart, yearEnd: c.yearEnd, neglectDays: c.neglectDays)
            XCTAssertEqual(got.total, c.expected.total, c.name)
            XCTAssertEqual(got.activeCount, c.expected.activeCount, c.name)
            XCTAssertEqual(got.newThisYearIDs, c.expected.newThisYearIDs, "\(c.name) — 올해")
            XCTAssertEqual(got.quietIDs, c.expected.quietIDs, "\(c.name) — 최근 기록 없음")
            XCTAssertEqual(got.noRecordIDs, c.expected.noRecordIDs, "\(c.name) — 기록 없음")
        }
    }

    func testTraitBuckets() throws {
        for c in try Self.loadGolden().traitBuckets {
            let got = TraitDistribution.buckets(c.items.map { (id: $0.id, values: $0.values) }, limit: c.limit)
            XCTAssertEqual(got.map(\.label), c.expected.map(\.label), c.name)
            XCTAssertEqual(got.map(\.count), c.expected.map(\.count), c.name)
            XCTAssertEqual(got.map(\.ids), c.expected.map(\.ids), c.name)
            XCTAssertEqual(got.map(\.isUnspecified), c.expected.map(\.isUnspecified), c.name)
            XCTAssertEqual(got.map(\.isRest), c.expected.map(\.isRest), c.name)
        }
    }

    func testGraphEdges() throws {
        for c in try Self.loadGolden().graphEdges {
            let people = c.people.map { GraphPerson(id: $0.id, name: $0.name, organization: $0.organization, introducedBy: $0.introducedBy) }
            let ties = c.ties.compactMap { pair in pair.count == 2 ? (pair[0], pair[1]) : nil }
            let got = RelationGraph.edges(people: people, records: c.records, ties: ties, organizationCliqueLimit: c.cliqueLimit)
            XCTAssertEqual(got.map(\.a), c.expected.map(\.a), c.name)
            XCTAssertEqual(got.map(\.b), c.expected.map(\.b), c.name)
            XCTAssertEqual(got.map(\.together), c.expected.map(\.together), c.name)
            XCTAssertEqual(got.map(\.introduced), c.expected.map(\.introduced), c.name)
            XCTAssertEqual(got.map(\.sameOrganization), c.expected.map(\.sameOrganization), c.name)
            XCTAssertEqual(got.map(\.acquainted), c.expected.map(\.acquainted), "\(c.name) — 아는 사이")
        }
    }

    func testLouvain() throws {
        for c in try Self.loadGolden().louvain {
            let links = c.links.map { CommunityDetection.Link(i: $0.i, j: $0.j, weight: $0.weight) }
            let got = CommunityDetection.louvain(nodeCount: c.nodeCount, links: links, resolution: c.resolution)
            XCTAssertEqual(got.communities, c.expected.communities, "\(c.name) — 그룹")
            XCTAssertEqual(got.modularity, c.expected.modularity, accuracy: 1e-9, "\(c.name) — 모듈성")
        }
    }

    func testSplitConnected() throws {
        for c in try Self.loadGolden().splitConnected {
            let links = c.links.map { CommunityDetection.Link(i: $0.i, j: $0.j, weight: $0.weight) }
            XCTAssertEqual(CommunityDetection.splitConnected(c.communities, nodeCount: c.nodeCount, links: links), c.expected, c.name)
        }
    }

    func testCommunityName() throws {
        for c in try Self.loadGolden().communityName {
            let members = c.members.map { CommunityNaming.Member(organization: $0.organization, tags: $0.tags ?? [], metThrough: $0.metThrough) }
            XCTAssertEqual(CommunityNaming.suggest(members), c.expected, c.name)
        }
    }

    func testInputReadiness() throws {
        for c in try Self.loadGolden().inputReadiness {
            let i = c.input
            let got = InputReadiness.evaluate(ReadinessInput(
                people: i.people, withFirstMet: i.withFirstMet, withRelationshipType: i.withRelationshipType,
                withMetThrough: i.withMetThrough, withRecords: i.withRecords, strongEdges: i.strongEdges, linkedPeople: i.linkedPeople))
            XCTAssertEqual(got.map(\.feature.rawValue), c.expected.map(\.feature), c.name)
            XCTAssertEqual(got.map(\.level.rawValue), c.expected.map(\.level), "\(c.name) — 단계")
            XCTAssertEqual(got.map(\.current), c.expected.map(\.current), "\(c.name) — 지금")
            XCTAssertEqual(got.map(\.hint), c.expected.map(\.hint), "\(c.name) — 할 일")
            for (g, e) in zip(got, c.expected) {
                XCTAssertEqual(g.progress, e.progress, accuracy: 1e-9, "\(c.name) — \(e.feature) 막대")
            }
            XCTAssertEqual(InputReadiness.summary(got), c.summary, "\(c.name) — 한 줄")
        }
    }

    func testPresetChoices() throws {
        for c in try Self.loadGolden().presetChoices {
            XCTAssertEqual(RelationshipPresets.choices(presets: c.presets, used: c.used), c.expected, c.name)
        }
    }

    func testContactSplit() throws {
        for c in try Self.loadGolden().contactSplit {
            XCTAssertEqual(ContactSorter.split(c.text), c.expected.fields, "\(c.text.debugDescription)")
        }
    }

    func testContactFromContact() throws {
        for c in try Self.loadGolden().contactFromContact {
            let phones = c.phones.map { ContactSorter.LabeledValue(label: $0.label, value: $0.value) }
            XCTAssertEqual(ContactSorter.fromContact(phones: phones, emails: c.emails), c.expected.fields,
                           "\(c.phones.map(\.label))")
        }
    }

    func testRecencySort() throws {
        for c in try Self.loadGolden().recencySort {
            let sorted = c.people.sorted {
                RecencySort.areInIncreasingOrder(
                    (lastRecordAt: $0.lastRecordAt.map { Date(timeIntervalSince1970: $0) }, name: $0.name, createdAt: Date(timeIntervalSince1970: $0.createdAt)),
                    (lastRecordAt: $1.lastRecordAt.map { Date(timeIntervalSince1970: $0) }, name: $1.name, createdAt: Date(timeIntervalSince1970: $1.createdAt)))
            }.map(\.name)
            XCTAssertEqual(sorted, c.expected, c.name)
        }
    }

    func testTimelineSort() throws {
        for c in try Self.loadGolden().timelineSort {
            let sorted = c.records.sorted {
                TimelineSort.areInIncreasingOrder(
                    (occurredAt: Date(timeIntervalSince1970: $0.occurredAt), createdAt: Date(timeIntervalSince1970: $0.createdAt)),
                    (occurredAt: Date(timeIntervalSince1970: $1.occurredAt), createdAt: Date(timeIntervalSince1970: $1.createdAt)))
            }.map(\.id)
            XCTAssertEqual(sorted, c.expected, c.name)
        }
    }

    func testNameValidation() throws {
        for c in try Self.loadGolden().validation {
            XCTAssertEqual(PersonValidation.nameProblem(c.name), c.expected, "이름 \(c.name.prefix(12))…")
        }
    }

    func testRecordSaveRule() throws {
        for c in try Self.loadGolden().recordSave {
            XCTAssertEqual(RecordValidation.canSave(title: c.title, note: c.note), c.expected,
                           "title=\(c.title ?? "nil") note=\(c.note ?? "nil")")
        }
    }

    func testDayNoon() throws {
        let parser = ISO8601DateFormatter()
        for c in try Self.loadGolden().dayNoon {
            let date = try XCTUnwrap(parser.date(from: c.iso), c.iso)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: c.timeZone), c.timeZone)
            let noon = DayNormalizer.noon(of: date, calendar: calendar)
            XCTAssertEqual(noon.timeIntervalSince1970, c.expectedEpoch, accuracy: 0.5, "\(c.iso) in \(c.timeZone)")
        }
    }

    func testSearch() throws {
        let golden = try Self.loadGolden()
        let people = golden.search.people.map { p in
            SearchablePerson(
                id: p.id, name: p.name, nickname: p.nickname, organization: p.organization,
                role: p.role, relationshipType: p.relationshipType, metThrough: p.metThrough,
                firstNote: p.firstNote, tags: p.tags,
                records: p.records.map {
                    SearchableRecord(id: $0.id, displayTitle: $0.displayTitle, title: $0.title,
                                     note: $0.note, location: $0.location, tags: $0.tags)
                })
        }
        for q in golden.search.queries {
            let hits = SearchMatcher.hits(SearchQuery(parsing: q.query), in: people)
            let got = hits.map { "\($0.personID.uuidString.lowercased())|\($0.kind.label)|\($0.evidence)|\($0.recordID?.uuidString.lowercased() ?? "-")" }
            let want = q.expected.map { "\($0.personID.uuidString.lowercased())|\($0.kind)|\($0.evidence)|\($0.recordID?.uuidString.lowercased() ?? "-")" }
            XCTAssertEqual(got, want, "검색어 '\(q.query)'")
        }
    }

    func testJosa() throws {
        for c in try Self.loadGolden().josa {
            XCTAssertEqual(Josa.eulReul(c.text), c.expected.eulReul, "'\(c.text)' 을/를")
            XCTAssertEqual(Josa.gwaWa(c.text), c.expected.gwaWa, "'\(c.text)' 과/와")
            XCTAssertEqual(Josa.iGa(c.text), c.expected.iGa, "'\(c.text)' 이/가")
        }
    }

    // MARK: - 정답표 밖의 성질

    func testQueryParsing() {
        let query = SearchQuery(parsing: "  #멘토 김 # ")
        XCTAssertEqual(query.terms, [
            SearchQuery.Term(text: "멘토", tagOnly: true),
            SearchQuery.Term(text: "김", tagOnly: false),
        ])
        XCTAssertTrue(SearchQuery(parsing: "   ").isEmpty)
    }

    func testRecordTypeFallsBackToOther() {
        XCTAssertEqual(RecordType.named("nope").key, "other")
        XCTAssertEqual(RecordType.named("meal").label, "식사")
        XCTAssertEqual(RecordType.all.count, 9)
    }
}
