import SwiftUI
import UIKit

/// 사람 상세의 연락 수단 다섯 줄 (FR-032 · 이슈 11). 빈 칸은 그리지 않는다.
///
/// 휴대전화 · 사무실 전화를 누르면 전화 앱, 이메일을 누르면 메일 앱이 열린다 (2026-10-18 사용자 결정).
/// 앱이 네트워크를 쓰는 것이 아니라 시스템 앱에 넘길 뿐이다. 길게 누르면 복사.
/// 한 줄(List 행) 안에 단추가 여럿이라 `.borderless` 로 둔다 — 아니면 줄 어디를 눌러도 모든 단추가 눌린다.
struct ContactRows: View {
    let person: Person

    @Environment(\.openURL) private var openURL

    var body: some View {
        let rows = items
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.label) { item in
                    row(item)
                }
            }
        }
    }

    private struct Item {
        let label: String
        let value: String
        let symbol: String
        let url: URL?
    }

    private var items: [Item] {
        var result: [Item] = []
        func add(_ label: String, _ value: String?, _ symbol: String, _ url: (String) -> URL?) {
            guard let value, !value.isEmpty else { return }
            result.append(Item(label: label, value: value, symbol: symbol, url: url(value)))
        }
        add("휴대전화", person.mobilePhone, "iphone", ContactLinks.telephone)
        add("사무실", person.officePhone, "phone", ContactLinks.telephone)
        add("팩스", person.faxNumber, "printer", { _ in nil })
        add("이메일", person.email, "envelope", ContactLinks.mail)
        add("기타", person.contactNote, "text.alignleft", { _ in nil })
        return result
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        let label = HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: item.symbol)
                .font(.scaled(14))
                .foregroundStyle(Color.muted)
                .frame(width: Font.scaledLength(20))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.label)
                    .font(.scaled(12))
                    .foregroundStyle(Color.muted)
                Text(item.value)
                    .font(.scaled(15))
                    .foregroundStyle(item.url == nil ? Color.bodyText : Color.accent)
                    .multilineTextAlignment(.leading)
            }
        }
        if let url = item.url {
            Button {
                openURL(url)
            } label: {
                label
            }
            .buttonStyle(.borderless)
            .contextMenu { copyButton(item.value) }
            .accessibilityHint(item.label == "이메일" ? "메일 앱을 엽니다" : "전화 앱을 엽니다")
        } else {
            label
                .textSelection(.enabled)
                .contextMenu { copyButton(item.value) }
        }
    }

    private func copyButton(_ value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
        } label: {
            Label("복사", systemImage: "doc.on.doc")
        }
    }
}

/// 전화 · 메일 주소를 시스템 앱으로 여는 주소로.
enum ContactLinks {
    /// 숫자와 맨 앞 `+` 만 남긴다 — `02-555-0101 (내선 3)` 같은 글은 내선 숫자가 붙어 버리므로, 괄호 앞까지만 본다.
    static func telephone(_ value: String) -> URL? {
        let main = value.split(separator: "(").first.map(String.init) ?? value
        var digits = String(main.filter { $0.isASCII && $0.isNumber })
        if main.trimmingCharacters(in: .whitespaces).hasPrefix("+") { digits = "+" + digits }
        guard digits.count >= 3 else { return nil }
        return URL(string: "tel:" + digits)
    }

    static func mail(_ value: String) -> URL? {
        let address = value.trimmingCharacters(in: .whitespaces)
        guard address.contains("@"), !address.contains(" ") else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        return components.url
    }
}
