import Core
import CoreText
import SwiftUI
import UIKit

/// **한 사람 내보내기** (FR-014 · D-54) — 한 사람의 정보와 기록 전체를 Markdown 또는 PDF 파일로 만들어 공유 시트에 넘긴다.
/// 글의 차례와 모양은 `Core.PersonExport` 하나 — PDF 도 같은 글에서 그린다. 파일은 임시 폴더에만 두고 앱이 어디로도 보내지 않는다.
@MainActor
enum PersonExporter {
    enum Format {
        case markdown
        case pdf
    }

    /// 화면에 보이는 글(날짜 정밀도 · 기기 형식)로 값을 만든다.
    static func value(of person: Person, now: Date = Date()) -> PersonExport.Person {
        let contacts: [PersonExport.Contact] = [
            ("휴대전화", person.mobilePhone), ("사무실", person.officePhone), ("팩스", person.faxNumber),
            ("이메일", person.email), ("기타", person.contactNote),
        ].compactMap { label, value in value.map { PersonExport.Contact(label: label, value: $0) } }
        let birthday: String? = {
            guard let month = person.birthMonth, let day = person.birthDay else { return nil }
            return BirthdayRule.text(month: month, day: day, year: person.birthYear)
        }()
        let records = RecordStore.timeline(of: person).map { record -> PersonExport.Record in
            let others = (record.participants ?? []).filter { !$0.isGone && !$0.isMe && $0 !== person }
            return PersonExport.Record(
                date: record.occurredAt.shown(precision: record.occurredPrecision, style: .long),
                type: record.type.label,
                title: record.displayTitle,
                note: record.note,
                location: record.location,
                tags: record.tags,
                companions: NameSort.sorted(others, name: \.name, createdAt: \.createdAt).map(\.name))
        }
        return PersonExport.Person(
            name: person.name, nickname: person.nickname, organization: person.organization, role: person.role,
            relationshipType: person.relationshipType, metThrough: person.metThrough,
            introducer: person.introducedBy.flatMap { $0.isGone ? nil : $0.name },
            birthday: birthday, tags: person.tags, contacts: contacts,
            firstMet: person.firstMetDate?.shown(precision: person.firstMetPrecision, style: .long),
            firstNote: person.firstNote, records: records,
            exportedOn: now.formatted(date: .long, time: .omitted))
    }

    /// 파일을 만들어 공유 시트를 띄운다. 만들지 못하면 false.
    @discardableResult
    static func share(_ person: Person, as format: Format) -> Bool {
        let markdown = PersonExport.markdown(value(of: person))
        guard let url = try? write(markdown, name: person.name, format: format) else { return false }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = controller.popoverPresentationController, let top = TopPresenter.topController() {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        TopPresenter.present(controller)
        return true
    }

    /// 임시 폴더에 파일 하나. 지난번 내보낸 파일은 지운다 — 기록이 담긴 파일을 남겨 두지 않게.
    static func write(_ markdown: String, name: String, format: Format) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("person-export", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safe = String(name.map { "/:\\?%*|\"<>".contains($0) ? "-" : $0 }).trimmingCharacters(in: .whitespaces)
        let base = (safe.isEmpty ? "사람" : safe) + " - 느린 인연"
        switch format {
        case .markdown:
            let url = folder.appendingPathComponent(base + ".md")
            try Data(markdown.utf8).write(to: url, options: .completeFileProtection)
            return url
        case .pdf:
            let url = folder.appendingPathComponent(base + ".pdf")
            try pdf(from: markdown).write(to: url, options: .completeFileProtection)
            return url
        }
    }

    /// Markdown 글을 A4 PDF 로 — 제목(#) · 구역(##) · 기록(###) · 항목(-) · 구분선(---) · 본문.
    /// 종이에 찍는 글이라 글자 크기를 숫자로 둔다(화면 글꼴 규칙은 화면에 대한 것이다). 색은 밝은 화면의 토큰 값.
    static func pdf(from markdown: String) -> Data {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let ink = UIColor(Color.ink).resolvedColor(with: light)
        let body = UIColor(Color.bodyText).resolvedColor(with: light)
        let muted = UIColor(Color.muted).resolvedColor(with: light)
        let accent = UIColor(Color.accent).resolvedColor(with: light)

        let text = NSMutableAttributedString()
        func add(_ line: String, size: CGFloat, weight: UIFont.Weight, color: UIColor, before: CGFloat, after: CGFloat) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = before
            style.paragraphSpacing = after
            style.lineSpacing = 2
            text.append(NSAttributedString(string: line + "\n", attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: style,
            ]))
        }
        for line in markdown.components(separatedBy: "\n") {
            if line.hasPrefix("### ") {
                add(String(line.dropFirst(4)), size: 13, weight: .semibold, color: ink, before: 10, after: 2)
            } else if line.hasPrefix("## ") {
                add(String(line.dropFirst(3)), size: 16, weight: .bold, color: accent, before: 16, after: 4)
            } else if line.hasPrefix("# ") {
                add(String(line.dropFirst(2)), size: 24, weight: .bold, color: ink, before: 0, after: 8)
            } else if line == "---" {
                add("", size: 6, weight: .regular, color: muted, before: 10, after: 0)
            } else if line.hasPrefix("- ") {
                add("· " + line.dropFirst(2), size: 11, weight: .regular, color: body, before: 0, after: 1)
            } else if line.hasPrefix("느린 인연에서 ") {
                add(line, size: 9, weight: .regular, color: muted, before: 6, after: 0)
            } else if !line.isEmpty {
                add(line, size: 11, weight: .regular, color: body, before: 0, after: 4)
            }
        }

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let frameRect = page.insetBy(dx: 48, dy: 56)
        let setter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        var start = 0
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            repeat {
                context.beginPage()
                let cg = context.cgContext
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: page.height)
                cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: frameRect, transform: nil)
                let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
                CTFrameDraw(frame, cg)
                cg.restoreGState()
                let shown = CTFrameGetVisibleStringRange(frame).length
                guard shown > 0 else { break }
                start += shown
            } while start < text.length
        }
    }
}
