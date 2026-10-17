# ADR-0001 · SwiftData, 기기 내 저장, CloudKit 제약은 첫 모델부터

**상태**: 채택 · 2026-10-17 (D-1)

## 맥락

개인용 앱이다. 다른 Apple ID 와 공유할 계획이 없다. 느린 부자의 가장 비싼 실수는 SwiftData 로 시작했다가 가족 공유(`CKShare`) 앞에서 Core Data 로 갈아탄 것이었고, 그 교훈은 "누구와 나눌 것인가를 먼저 묻는다 — 한 사람이 여러 기기면 SwiftData 로 충분하다" 였다.

## 결정

- 저장 계층은 **SwiftData**. 스키마는 `SchemaV1` 부터 판을 쌓는다(`VersionedSchema` + `SchemaMigrationPlan`).
- POC 는 **기기 내 저장만**. `cloudKitDatabase: .none`.
- 그러나 **CloudKit 제약을 첫 모델부터 지킨다**: 유니크 제약 없음 · 모든 속성에 기본값 또는 옵셔널 · 모든 관계 옵셔널. 나중에 아이폰 ↔ 아이패드 동기화(개인 DB)를 켤 때 스키마를 다시 만들지 않으려고.
- 고유 식별자 칸 이름은 `uuid` — `PersistentModel` 이 `id` 를 이미 쓴다.
- 저장소 파일 이름 `SlowConnection` 은 바꾸지 않는다. 바꾸면 빈 저장소를 새로 열어 사용자에게는 기록이 사라진 것으로 보인다.

## 대안

| 대안 | 기각 이유 |
|---|---|
| Core Data + CloudKit (느린 부자 방식) | 가족 · 타인 공유가 필요할 때의 선택. 개인 기록 앱에는 보일러플레이트와 스키마 세 벌 대조가 과하다 |
| SwiftData + iCloud 처음부터 | 첫 빌드 전에 컨테이너 · 스키마 배포 · Production 승격이 필요하다. POC 의 핵심(기록 경험)과 무관한 비용 |
| SQLite(GRDB) | 서드파티 의존 하나 추가. 동기화를 직접 만들어야 한다 |

## 결과

- 동기화를 켜는 날 할 일: App ID 에 iCloud 켜기 · 컨테이너 `iCloud.com.helpnara.slow.connection` · `ModelConfiguration(cloudKitDatabase: .private(...))` · CloudKit 스키마를 Development 에 밀어 넣고(느린 부자 `Tools/cloudkit` 방식) 사람이 Production 에 Deploy.
- 참여자 N:M 과 자기참조(`introducedBy`)가 SwiftData 에서 제약 아래 동작하는지는 가정 A2 — 첫 CI 의 앱 테스트가 확인한다.
