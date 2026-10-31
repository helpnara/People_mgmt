# 아키텍처 결정 기록 (ADR)

되돌리기 비싼 결정만 기록한다. 각 문서는 **맥락 → 결정 → 대안 → 결과** 순서다. 나머지 결정은 요구사항 정의서 부록 A 에 있다.

| # | 제목 | 상태 |
|---|---|---|
| [0001](0001-swiftdata-local-first.md) | SwiftData, 기기 내 저장, CloudKit 제약은 첫 모델부터 | 채택 (2026-10-17) · 동기화는 0005 로 갱신 |
| [0002](0002-core-package.md) | 순수 로직은 `Packages/Core` — Foundation 만, 리눅스에서 테스트 | 채택 |
| [0003](0003-record-participants.md) | 기록은 참여자 N:M, 첫 인연은 사람의 속성 | 채택 |
| [0004](0004-metrics-do-not-score-people.md) | 관계 지표는 사람을 점수화하지 않는다 | 채택 |
| [0005](0005-icloud-sync.md) | 아이폰 ↔ 아이패드 동기화는 내 iCloud 비공개 영역으로 | 채택 (2026-10-19) |
