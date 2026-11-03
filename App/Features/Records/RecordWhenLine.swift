import SwiftUI

/// 기록 줄 맨 위의 날짜 한 줄 — `앞말 · 날짜 시각 · 표시 · 덧말` (이슈 68 · 2026-11-03 사용자).
///
/// 한 줄에 다 들어가면 그대로 한 줄. 안 들어가면 **칸을 나눈다** — `앞말 | 날짜 / 시각 | 표시 · 덧말`(빌드 46 실기기:
/// 시각 뒤에 함께한 사람을 붙여 두 줄로 꺾으니 사람과 섞여 보였다). 날짜 칸은 날짜 아래에 시각을 두고, 덧말 칸은 남는 폭에서 꺾인다.
/// 큰 글씨(접근성 크기)에서는 칸이 너무 좁아지므로 위아래로 쌓는다.
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

    @Environment(\.dynamicTypeSize) private var typeSize

    private var hasTail: Bool { badge != nil || !(extra ?? "").isEmpty }

    var body: some View {
        if typeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                oneLine
                columns
            }
        }
    }

    /// 한 줄 — `3일 후 2026년 11월 11일 오후 5:30 · 이름, 이름 외 1명`.
    private var oneLine: some View {
        HStack(spacing: 6) {
            leadText
            Text(time.map { date + " " + $0 } ?? date)
            if let badge { accent("· " + badge) }
            if let extra, !extra.isEmpty { Text("· " + extra) }
        }
    }

    /// 칸 나누기 — 앞말 | 날짜 / 시각 | 표시 · 덧말. 칸 사이는 가는 세로줄.
    private var columns: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            leadText
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                if let time { Text(time) }
            }
            .fixedSize()
            if hasTail {
                divider
                VStack(alignment: .leading, spacing: 2) {
                    if let badge { accent(badge) }
                    if let extra, !extra.isEmpty {
                        Text(extra).readableLineLimit(2)
                    }
                }
            }
        }
    }

    /// 큰 글씨 — 앞말 날짜 / 시각 / 표시 · 덧말을 위아래로.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                leadText
                Text(date)
            }
            if let time { Text(time) }
            if let badge { accent(badge) }
            if let extra, !extra.isEmpty { Text(extra) }
        }
    }

    /// 칸 사이 가는 세로줄 — 글자 높이만큼.
    private var divider: some View {
        Rectangle()
            .fill(Color.rule)
            .frame(width: 1, height: Font.scaledLength(14))
            // 줄에는 글자 밑줄(baseline)이 없다 — 아래 끝을 밑줄보다 조금 내려 글자 높이에 맞춘다.
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - Font.scaledLength(2) }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var leadText: some View {
        if let lead { accent(lead) }
    }

    private func accent(_ text: String) -> some View {
        Text(text)
            .fontWeight(.semibold)
            .foregroundStyle(Color.accent)
    }
}
