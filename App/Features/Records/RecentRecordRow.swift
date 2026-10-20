import Core
import SwiftUI

/// 홈의 최근 기록 한 줄 (FR-028): 유형 아이콘 · 날짜 · 함께한 사람 · 표시명.
struct RecentRecordRow: View {
    let record: Record

    var body: some View {
        // 지운 기록은 다시 그리지 않는다 (CLAUDE.md · 이슈 27).
        if record.isGone {
            EmptyView()
        } else {
            row
        }
    }

    /// 함께한 사람 — 나를 빼고 이름 순으로 둘까지, 나머지는 `외 n명`.
    private var companions: String {
        let others = (record.participants ?? []).filter { !$0.isGone && !$0.isMe }
        let names = NameSort.sorted(others, name: \.name, createdAt: \.createdAt).map(\.name)
        guard !names.isEmpty else { return "" }
        let shown = names.prefix(2).joined(separator: ", ")
        return names.count > 2 ? "\(shown) 외 \(names.count - 2)명" : shown
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.type.symbol)
                .font(.scaled(15))
                .foregroundStyle(Color.accent)
                .frame(width: Font.scaledLength(22))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.occurredAt.shown(precision: record.occurredPrecision, style: .abbreviated))
                    if !companions.isEmpty {
                        Text("· \(companions)")
                            .readableLineLimit(1)
                    }
                }
                .font(.scaled(13))
                .foregroundStyle(Color.muted)
                Text(record.displayTitle)
                    .font(.scaled(16, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .readableLineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
