# ADR-0005 · 아이폰 ↔ 아이패드 동기화는 내 iCloud 비공개 영역으로 (SwiftData + CloudKit)

**상태**: 채택 · 2026-10-19 (D-42 · D-43 · D-44)

## 맥락

사용자: *아이폰에서 등록된 정보가 나의 아이패드에서도 볼 수 있게 동기화하는 작업을 우선 진행하자. 아이패드에서 연락처를 빠르게 입력할 수 있으니깐.*
ADR-0001 이 이날을 위해 CloudKit 제약(유니크 없음 · 모든 속성 기본값/옵셔널 · 모든 관계 옵셔널 · 역관계)을 첫 모델부터 지켜 왔다. 한 사람이 여러 기기를 쓰는 경우라 공유(`CKShare`)는 필요 없다 — SwiftData 의 개인 DB 동기화로 충분하다.

## 결정

- 저장소를 `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.helpnara.slow.connection"))` 로 연다. 개발자 서버는 없고, 자료는 사용자의 iCloud 비공개 영역에만 있다.
- **설정에서 켜고 끈다, 기본 켬** (D-42). 바꾸면 앱을 다시 열 때 적용 — 저장소를 연 뒤에는 바꿀 수 없다.
- **스키마는 CI 가 만들고 사람이 배포한다** (느린 부자 방식 · 2026-10-19 개정). TestFlight · App Store 판은 CloudKit **배포 환경(Production)** 만 쓰고, 배포 환경에는 앱이 스키마를 만들 수 없다.
  1. `Tools/cloudkit/generate-ckdb.py` 가 `Schema.swift` 의 지금 판에서 스키마 파일(`slowconnection.ckdb`)을 만든다 — SwiftData 가 쓰는 이름 규칙(`CD_<모델>` · `CD_<칸>` · 길이가 변하는 값의 `_ckAsset` · 하나로 가는 관계는 STRING · 여럿 ↔ 여럿의 `CDMR`)을 따르고 **넘치게** 둔다.
  2. `cloudkit-schema.yml`(리눅스 · CKTool JS · 관리 토큰)이 **개발 환경**에 적용한다.
  3. 사용자가 CloudKit 콘솔에서 Production 으로 배포한다.
  4. 동기화 판(`CloudSync.mainStoreSyncAvailable = true`): 진짜 저장소를 처음으로 잇는다 — 처음 잇는 저장소라 기존 자료가 빠짐없이 올라간다.
- **설정에 마지막 동기화 때와 실패를 보인다** (`CloudSyncMonitor` · `NSPersistentCloudKitContainer.eventChangedNotification`). 스키마에 빠진 칸이 있으면 여기 실패로 나타난다 — 자료는 기기에 그대로 있고, 칸을 더해 다시 배포하면 이어서 올라간다.
- **나는 하나** (D-43): 두 기기에서 따로 나를 적어 둘이 되면 먼저 만든 나만 남기고 나머지는 보통 사람으로 바꾼다(지우지 않음), 한 번 알린다.
- **동기화가 켜져 있으면 백업 복원을 막는다** (D-44) — 복원한 사람과 iCloud 의 사람이 둘씩 생긴다.
- 다른 기기의 변경은 `NSPersistentStoreRemoteChange` 로 받아 목록 정렬 · 색인 · 요약을 다시 센다. 조용한 푸시(`remote-notification`)로 깨어 내려받는다.

- **저장 파일 보호는 처음 잠금 해제 후 보호** (D-48 · 이슈 31, 2026-10-20). 동기화는 잠긴 동안에도 깨어나 저장소를 읽는다 — 완전 보호 파일은 그때 시스템이 앱을 끈다(빌드 21 아이패드 크래시). 화면 쪽 셈은 앱이 앞에 있고 잠기지 않았을 때만(`StoreAccess`), 그동안 들어온 변경은 앞으로 나올 때 한 번에 센다.

## 대안

| 대안 | 기각 이유 |
|---|---|
| 바로 진짜 저장소를 잇고 개발 환경에서 시험 | 개발 환경에 올라간 자료는 배포 환경으로 옮겨지지 않는다. 같은 저장소를 배포 환경에 다시 이을 때 이미 올린 것으로 여겨 빠질 위험 |
| 앱 안에서 `initializeCloudKitSchema()` (처음 고른 길) | 개발 환경에 붙은 판이 있어야 하는데, App Store Connect 로 내보내는 판은 `iCloudContainerEnvironment = Development` 를 거부한다 (빌드 20 실행 실패). 맥이 없어 개발 판을 기기에 직접 깔 수도 없다 |
| Core Data + CloudKit 으로 갈아타기 | 공유가 필요 없다. 지금 모델 그대로 SwiftData 가 동기화한다 |
| 직접 서버 | 네트워크 요청을 하지 않는다는 원칙(CLAUDE.md §2)에 어긋난다 |

## 결과

- 콘솔 절차는 `docs/06-ci.md` §7. 스키마를 바꾸는 판(6판 …)마다 **스키마 파일 다시 만들기 → 개발 환경에 적용 → Production 배포** 를 되풀이한다 (`core-test.yml` 이 파일이 모델과 같은지 검사) — 배포 환경에서는 칸을 지울 수 없고 더하기만 된다(SwiftData 가벼운 옮기기와 같은 방향).
- 처리방침 · 설정의 개인정보 문구 · 스토어 설명을 동기화 판에서 고친다.
- 큰 자료(5,000명 · 명함 사진)는 처음 올리는 데 시간이 걸린다 — 이 기기의 자료는 그대로이고 다른 기기에 차례로 나타난다.
