import SwiftUI

/// 타임라인 한 줄 (요구사항 4.2.3): 유형 아이콘 · 날짜 · 표시명 · 메모 첫 줄 · 장소 · 외 N명 · 태그.
struct TimelineRow: View {
    let record: Record
    let viewer: Person

    var body: some View {
        // 지운 기록은 다시 그리지 않는다 (CLAUDE.md · 이슈 27) — 빌드 16 에서 기록을 지운 직후 이 줄이 지운 기록의
        // 장소 · 태그를 읽다 앱이 꺼졌다. 줄 맨 위에서 거른다.
        if record.isGone {
            EmptyView()
        } else {
            row
        }
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
                    if record.otherParticipantCount(besides: viewer) > 0 {
                        Text("· 외 \(record.otherParticipantCount(besides: viewer))명")
                    }
                }
                .font(.scaled(13))
                .foregroundStyle(Color.muted)
                Text(record.displayTitle)
                    .font(.scaled(16, weight: .medium))
                    .foregroundStyle(Color.ink)
                if let preview = record.notePreview {
                    Text(preview).font(.scaled(14)).foregroundStyle(Color.bodyText).readableLineLimit(1)
                }
                // 장소 · 태그는 줄을 넘으면 접는다 — 큰 글씨에서 한 줄에 다 서지 않는다 (D-33).
                WrapLayout(spacing: 8) {
                    if let location = record.location, !location.isEmpty {
                        // `Label` 은 이 흘림 배치 안에서 글자가 빠지고 핀만 남았다(이슈 48 · 이슈 34 의 칩과 같은 꼴) — 그림과 글자를 따로.
                        HStack(spacing: 3) {
                            Image(systemName: "mappin").accessibilityHidden(true)
                            Text(location).readableLineLimit(1)
                        }
                        .font(.scaled(12))
                        .foregroundStyle(Color.muted)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("장소 \(location)")
                    }
                    ForEach(record.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)").font(.scaled(12)).foregroundStyle(Color.chipInk)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
