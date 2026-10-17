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
        struct Hit: Decodable { let personID: UUID; let kind: String; let evidence: String }
        struct Query: Decodable { let query: String; let expected: [Hit] }
        struct Search: Decodable { let people: [Person]; let queries: [Query] }
        struct JosaExpected: Decodable { let eulReul: String; let gwaWa: String; let iGa: String }
        struct JosaCase: Decodable { let text: String; let expected: JosaExpected }

        let tags: [TagCase]
        let tagSplit: [SplitCase]
        let displayTitle: [TitleCase]
        let nameSort: [SortCase]
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
            let got = hits.map { "\($0.personID.uuidString.lowercased())|\($0.kind.label)|\($0.evidence)" }
            let want = q.expected.map { "\($0.personID.uuidString.lowercased())|\($0.kind)|\($0.evidence)" }
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
