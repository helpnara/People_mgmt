import SwiftUI

/// 기록 줄 맨 위의 날짜 한 줄 — `앞말 · 날짜 시각 · 표시 · 덧말` (이슈 68 · 2026-11-03 사용자).
///
/// 한 줄에 다 들어가면 그대로 한 줄. 안 들어가면 **날짜 다음에서만** 꺾는다 — 날짜 칸이 좁아져 `오후` 와 `5:30` 사이처럼
/// 아무 데서나 줄이 바뀌지 않게(빌드 44 실기기 사진). 두 줄일 때는 `앞말 날짜` / `시각 · 표시 · 덧말`.
/// 글꼴 · 색은 부르는 쪽이 준다(앞말 · 표시만 강조색). 다가오는 만남 · 결과를 적을 만남 · 최근 기록 · 타임라인이 같이 쓴다.
struct RecordWhenLine: View {
    let date: String
    let time: String?
    /// 날짜 앞의 강조 글 — `3일 후` · `결과 적기`.
    var lead: String?
    /// 시각 뒤의 강조 글 — `예정 3일 후`.
    var badge: String?
    /// 끝의 보조 글 — `이름, 이름 외 1명` · `외 2명`.
    var extra: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                leadText
                Text(time.map { date + " " + $0 } ?? date)
                badgeText(dotted: true)
                extraText(dotted: true)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    leadText
                    Text(date)
                }
                if time != nil || badge != nil || extra != nil {
                    HStack(spacing: 6) {
                        if let time { Text(time) }
                        badgeText(dotted: time != nil)
                        extraText(dotted: time != nil || badge != nil)
                            .readableLineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var leadText: some View {
        if let lead {
            Text(lead)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accent)
        }
    }

    @ViewBuilder
    private func badgeText(dotted: Bool) -> some View {
        if let badge {
            Text(dotted ? "· " + badge : badge)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accent)
        }
    }

    @ViewBuilder
    private func extraText(dotted: Bool) -> some View {
        if let extra, !extra.isEmpty {
            Text(dotted ? "· " + extra : extra)
        }
    }
}
