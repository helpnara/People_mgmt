import SwiftUI

/// 저장소를 끝내 못 열었을 때 (요구사항 7.5 · 느린 부자 docs/18 5-4).
/// 저장소 · 모델을 하나도 안 쓴다. **지우기 단추를 두지 않는다** — 사용자 자료를 앱이 고르게 하지 않는다.
struct StoreFailureView: View {
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.scaled(40))
                .foregroundStyle(Color.danger)
            Text("기록을 열지 못했습니다")
                .font(.scaled(22, weight: .bold))
                .foregroundStyle(Color.ink)
            Text("기록은 지워지지 않았습니다. 앱을 완전히 종료한 뒤 다시 열어 보세요. 기기 저장 공간이 부족하지 않은지도 확인해 주세요. 계속 이 화면이 보이면 아래 내용을 복사해 문의해 주세요.")
                .font(.scaled(16))
                .foregroundStyle(Color.bodyText)
            Text(reason)
                .font(.scaled(13).monospaced())
                .foregroundStyle(Color.muted)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.raised, in: RoundedRectangle(cornerRadius: 10))
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ground)
    }
}
