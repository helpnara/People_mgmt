import Core
import SwiftUI

/// 홈의 최근 기록 한 줄 (FR-028): 유형 아이콘 · 날짜 · 표시명 · 장소와 함께한 사람.
/// 다가오는 만남 · 결과를 적을 만남(D-62) · 만나기 전에의 지난 기록 · 한 해 돌아보기 · 기록 찾기도 같은 줄이다 —
/// 날짜 앞에 `lead`(`3일 후` · `결과 적기`)를 붙인다. 1.1.11(이슈 110)부터 늘 세 줄이라 줄마다 높이가 같다.
/// 장소 표시는 타임라인과 같은 핀 아이콘(`mappin`)이다 — `@` 는 이메일처럼 읽힌다(2026-11-12 사용자 · 고르기를 맡김).
struct RecentRecordRow: View {
    let record: Record
    var lead: String?

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

    /// 장소 (1.1.11 · 이슈 110) — 비었으면 nil.
    private var place: String? {
        let text = (record.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// 셋째 줄 — 장소 · 함께한 사람 (1.1.11 · 이슈 110 · 2026-11-12 사용자). 줄마다 높이가 같게 늘 한 줄을 둔다 —
    /// 둘 다 없으면 빈칸 한 줄(읽어 주지 않는다).
    @ViewBuilder
    private var detailLine: some View {
        if place == nil && companions.isEmpty {
            Text(" ").accessibilityHidden(true)
        } else {
            HStack(spacing: 4) {
                if let place {
                    // `Label` 은 줄이 좁을 때 글자가 빠지고 그림만 남았다(이슈 48) — 그림과 글자를 따로.
                    Image(systemName: "mappin")
                        .font(.scaled(11, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .accessibilityHidden(true)
                    Text(companions.isEmpty ? place : place + " · ")
                        .accessibilityLabel("장소 \(place)")
                        .layoutPriority(1)
                }
                if !companions.isEmpty {
                    Text(companions)
                }
            }
        }
    }

    /// 한 줄씩 셋 — 날짜(앞말 · 시각) / 제목 / 장소 · 함께한 사람. 줄마다 한 줄로 잘라 줄 높이가 같다 (이슈 110).
    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.type.symbol)
                .font(.scaled(15))
                .foregroundStyle(Color.accent)
                .frame(width: Font.scaledLength(22))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                // 길면 날짜 다음에서만 꺾는다 (이슈 68). 함께한 사람은 셋째 줄로 옮겼다 (이슈 110).
                RecordWhenLine(date: record.dateText(style: .abbreviated), time: record.timeText, lead: lead)
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
                Text(record.displayTitle)
                    .font(.scaled(16, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .readableLineLimit(1)
                detailLine
                    .font(.scaled(13))
                    .foregroundStyle(Color.muted)
                    .readableLineLimit(1)
            }
            // 첫 사진 작은 그림 (9판 · FR-058) — 사진이 없으면 자리를 차지하지 않는다(함께한 사람처럼 관계만 본다 · 풀기는 .task).
            if record.hasPhotos {
                Spacer(minLength: 0)
                RecordRowThumbnail(record: record)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
