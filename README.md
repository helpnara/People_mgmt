# 느린 인연 — iPhone 앱

사람을 저장하는 데서 끝나지 않고, **사람과 나 사이에 쌓인 인연의 역사**를 기록하는 개인용 iOS 앱입니다.
이 사람을 어떻게 알게 되었고, 함께 무엇을 했는지를 시간순으로 남기고 다시 찾아봅니다.
서버 없이 기기에만 저장합니다. 느린 시리즈(느린 부자 · 느린 여백)의 셋째 앱입니다.

| 항목 | 결정 |
|---|---|
| 플랫폼 | iOS 17+ · iPhone 우선 · iPad 도 설치됨 (유니버설) |
| UI | SwiftUI |
| 영속성 | SwiftData, 기기 내 저장. CloudKit 제약을 첫 모델부터 지켜 동기화를 나중에 켤 수 있게 둔다 ([ADR-0001](docs/adr/0001-swiftdata-local-first.md)) |
| 백엔드 | 없음. 네트워크 요청이 하나도 없다 |
| 개발 환경 | 맥 없음 — 리눅스 원격 세션이 코드를 쓰고 GitHub Actions 의 macOS 러너가 빌드 · 스크린샷 · TestFlight 를 한다 ([06-ci](docs/06-ci.md)) |
| 번들 ID | `com.helpnara.slow.connection` · 타깃 `SlowConnection` · 표시 이름 `느린 인연` |

## 지금 무엇이 만들어져 있나

**2단계(사람 관리)까지** — 사람 목록 · 추가 · 수정 · 삭제 · 상세 · 검색 · 태그 · 소개 관계. 기록 · 타임라인은 3단계다.
최신은 [로드맵](docs/roadmap.md)의 "지금 어디까지".

화면은 매 푸시마다 CI 가 시뮬레이터에서 찍어 [`screenshots/`](screenshots/)에 되돌려 커밋합니다.

## 설계 문서

1. [요구사항 정의서 v0.5](docs/requirements-v0.5.md) — 화면 · 데이터 모델 · 검색 · 검증 · 비기능 · 수용 기준. **확정본**
2. [로드맵](docs/roadmap.md) — 지금 어디까지, 1.0 의 정의, 안정화 기준, 가정 표
3. [CI · TestFlight 절차](docs/06-ci.md) — 맥 없이 내 폰까지, 처음 한 번 사용자가 할 일
4. [열린 이슈](docs/08-feedback.md)
5. [아키텍처 결정 기록(ADR)](docs/adr/)
6. 검토 기록 — [v0.1 검토 의견서](docs/requirements-review-v0.1.md) · [관계 지표(SNA) 검토](docs/sna-metrics-review.md)

[개인정보 처리방침](docs/privacy.md) — 앱이 무엇을 모으지 않는지

## 개인정보에 관한 원칙

이 저장소에는 **실제 사람의 이름 · 소속 · 연락처 · 메모를 커밋하지 않습니다.** 견본 자료와 문서의 사람은 전부 지어낸 것입니다.
앱도 같은 원칙입니다 — 네트워크 요청이 없고, 분석 도구도 없으며, 자료는 사용자 기기에만 있습니다.

## macOS 에서 빌드하려면

```bash
brew install xcodegen
xcodegen generate                      # SlowConnection.xcodeproj 생성 (커밋하지 않는다)
cd Packages/Core && swift test && cd - # 순수 로직 테스트 (수 초)
open SlowConnection.xcodeproj          # ⌘R
```
