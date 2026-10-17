import SwiftUI

/// 타임라인 한 줄 (요구사항 4.2.3): 유형 아이콘 · 날짜 · 표시명 · 메모 첫 줄 · 장소 · 외 N명 · 태그.
struct TimelineRow: View {
    let record: Record
    let viewer: Person

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.type.symbol)
                .font(.scaled(15))
                .foregroundStyle(Color.accent)
                .frame(width: Font.scaledLength(22))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.occurredAt.formatted(date: .abbreviated, time: .omitted))
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
                    Text(preview).font(.scaled(14)).foregroundStyle(Color.bodyText).lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let location = record.location, !location.isEmpty {
                        Label(location, systemImage: "mappin").font(.scaled(12)).foregroundStyle(Color.muted).lineLimit(1)
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
