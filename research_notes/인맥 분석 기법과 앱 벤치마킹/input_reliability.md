# 입력 편의 · 자료 수집 · 신뢰성/개인정보 — 개인 CRM 앱 벤치마킹과 iOS 플랫폼 기능 (2024–2026)

> 조사일 2026-10-18. 웹 검색 16회 기준. 벤더 자료(자사 블로그 · 앱스토어 소개문)는 그렇다고 표시했다.
> 이 저장소의 현재 상태(대조용): 명함 촬영 + 기기 내 OCR 제안(FR-050) · 연락처 선택기로 1건 가져오기(FR-015) · 빠른 연속 등록(FR-051) · 백업 JSON(FR-018, 빌드 13)은 **이미 있다**. 위젯 · 단축어는 요구사항에 "나중" 목록(`docs/requirements-v0.5.md` 868행)으로만 있다.

## 1. 타사 앱은 사람 · 만남을 어떻게 받아들이나 (명함 · 연락처 · 캘린더 · 연동)

### Takeaway
클라우드형 개인 CRM(Dex · Clay)은 **외부 계정 동기화(LinkedIn · Gmail · 캘린더 · 메신저)로 입력 자체를 없애는** 쪽이고, 명함 앱은 **정확도를 사람 검수(리멤버 초기)나 클라우드 AI(Covve)로 확보**한다. 둘 다 네트워크 전제라 이 앱이 그대로 쓸 수 없고, 기기 안에서 같은 효과를 내는 것은 "명함 OCR + 사용자 확인", "연락처 선택기", "캘린더 일정에서 기록 제안" 정도다.

### Cited Findings
- **Dex — 명함:** 카드를 읽어 양식을 미리 채우고 사용자가 고쳐서 제출하며, 명함 사진도 새 연락처에 저장한다 — [Dex 도움말: card scanner](https://guidev3.getdex.com/workflows/card-scanner)
- **Dex — 캘린더:** Google Calendar 동기화로 여러 계정의 일정을 Dex 안에 가져오고, 회의 이력 보기 · 회의 메모 추가가 된다 — [Dex docs](https://getdex.com/docs/dex-core); [ataiva 요약](https://ataiva.com/ai/dex/)
- **Dex — LinkedIn:** 연결을 가져와 약력 · 경력 · 학력을 채우고 직함 변경을 추적, 브라우저 확장으로 LinkedIn에서 바로 추가 — [Dex docs](https://getdex.com/docs/dex-core). LinkedIn 동기화는 유료 기능(2026 리뷰) — [dupple 리뷰](https://dupple.com/reviews/dex)
- **Dex — 수집 범위(자사 주장):** LinkedIn(최대 9,000명) · Gmail · Outlook · WhatsApp · iMessage · Instagram · Facebook · X 를 한 데이터베이스로 모은다 — [Dex 블로그(벤더)](https://getdex.com/blog/contact-management-software/)
- **Dex 가격(벤더 블로그, 2026-07):** Premium 월 $12 · Professional 월 $20 — [Dex vs Wave Connect(벤더)](https://getdex.com/blog/dex-vs-wave-connect/)
- **Clay — iOS 연락처는 읽기 전용:** Clay에서 고친 내용이 iPhone 연락처로 돌아가지 않는다. 연락처를 영구 삭제하는 옵션이 없다 — [Clay 도움말 FAQ](https://library.me.sh/hc/en-us/articles/6925346551835-How-does-Clay-affect-my-iOS-Contacts)
- **Covve Scan — 정확도(벤더 주장):** 60개 이상 언어, CamCard · ABBYY · BizConnect보다 정확하고 빠르다고 앱스토어 소개문에서 주장 — [App Store: Covve](https://apps.apple.com/app/id1459654107). Capacitor Partners의 비교 "연구"도 Covve 우위라 하지만 보도자료이고 방법론 미공개 — [SalesTechStar 보도자료](https://salestechstar.com/predictive-ai-artificial-intelligence/new-study-finds-ai-powered-business-card-scanner-covve-has-the-speed-and-accuracy-needed-for-us-to-finally-have-paperless-meetings/)
- **Covve vs CamCard 사용자 평:** 한 사용자가 Covve가 CamCard보다 글자 인식이 훨씬 정확해 갈아탔다고 적음(2022, 1건) — [Software Advice 리뷰](https://www.softwareadvice.com/ocr/covve-scan-profile/reviews/). GetApp 평점 CamCard 4.4(17건) · Covve 4.9(18건), 표본이 작다 — [GetApp 비교](https://www.getapp.com.au/compare/126343/2059245/camcard/vs/covve-scan)
- **리멤버 — 사람이 입력해 정확도 확보:** 초기에 "손으로 직접 입력해 정확도를 높인 수기 명함관리 앱", "노동집약형"이라는 평을 받았다. 2020년 기준 회원 300만 · 누적 명함 2억 장 — [바이라인네트워크 칼럼(2020)](https://byline.network/2020/07/29-72/) (원문 접속 실패, 검색 요약 기준). 현재 앱스토어 소개문은 "촬영만 하면 자동 저장" — [App Store: 리멤버](https://apps.apple.com/us/app/%EB%A6%AC%EB%A9%A4%EB%B2%84-no-1-%EA%B2%BD%EB%A0%A5%EC%B1%84%EC%9A%A9-%EB%AA%85%ED%95%A8%EA%B4%80%EB%A6%AC-%EC%BB%A4%EB%AE%A4%EB%8B%88%ED%8B%B0/id840553277?l=pt-BR); 리멤버 수익 모델 기사 — [한경비즈니스(2018)](https://magazine.hankyung.com/business/article/201808140666b)
- **Monica(오픈소스) — 활동 기록:** 식사 · 통화 · 여행 · 이벤트 이력을 남긴다 — [monicahq.com](https://monicahq.com/). 포크 기능 목록에 사용자 정의 활동 유형 · SNS/SMS 대화 추적 · 기본 저널 — [GitHub 포크](https://github.com/bitnovus/monica)
- **Monica — 자체 호스팅 부담:** 서버 운영 · 업데이트 · 백업을 사용자가 맡는다(경쟁사 가이드) — [folk.app](https://www.folk.app/zh/articles/personal-crm)

### Inferences
**(1) 입력 방식 표 — 방식 → 쓰는 앱 → iOS API → 권한/개인정보 비용 → 이 앱에서의 노력**

| 입력 방식 | 쓰는 앱(확인된 것) | iOS API | 권한 · 개인정보 비용 | 노력 / 이 앱 현황 |
|---|---|---|---|---|
| 명함 촬영 → 글자 읽기 → 칸 제안 | Dex, Covve, CamCard, 리멤버 | VisionKit `VNDocumentCameraViewController` · Vision 글자 인식 · `DataScannerViewController`(실시간) | 카메라 권한 1회. 기기 내 처리면 수집 없음. 클라우드/사람 검수는 명함 이미지가 서버로 감 | **이미 있음**(FR-050). 남은 것: 정확도 개선(정답표 확장), 실시간 스캐너는 선택 |
| 연락처 1건 고르기 | (일반적) | `CNContactPickerViewController` | **권한 없음**(선택기는 고른 1건만 앱에 전달) | **이미 있음**(FR-015) |
| 연락처 여러 명 가져오기 + 중복 병합 | Dex, Clay, Covve | Contacts `CNContactStore` + iOS 18 제한 접근 · `ContactAccessButton` | 전체/제한 연락처 권한. 제한 접근이면 고른 사람만 | 중간. 중복 판정 규칙은 Core 정답표로 검증 가능 |
| 캘린더 일정 → "이 만남을 기록할까요" | Dex(Google Calendar), Clay | EventKit `requestFullAccessToEvents` | **전체 캘린더 읽기** 권한 — 가장 무거운 권한 중 하나. 기기 내만 읽으면 수집 아님 | 중간~큼. 읽기만, 저장은 기록 1건 |
| LinkedIn · Gmail · 메신저 동기화 | Dex, Clay | (해당 없음 — 서버 API) | 계정 토큰 · 서버 저장 필수 | **이 앱 원칙(네트워크 0)과 충돌 — 제외** |
| 공유 확장(다른 앱에서 텍스트 · 사진 · vCard 보내기) | (Dex 브라우저 확장이 유사) | Share Extension · `.vcf` 열기(UTType) | 권한 없음. 사용자가 고른 것만 받음 | 중간. App Group 저장소 공유 필요 |
| 받아쓰기 · 음성 메모 → 글자 | (확인된 CRM 사례 없음) | 키보드 받아쓰기(시스템) · `SpeechAnalyzer`(iOS 26) · `SFSpeechRecognizer` | 앱 내 녹음은 마이크 + 음성 인식 권한. 기기 내 모델이면 수집 없음 | 키보드 받아쓰기는 0. 앱 내 녹음 버튼은 중간 |
| 빠른 추가 위젯 · 단축어 · Siri | (확인된 CRM 사례 없음) | App Intents · 대화형 위젯(iOS 17) · App Shortcuts | 권한 없음 | 작음~중간. 위젯 확장 타깃 + App Group |
| 저널 제안(만난 사람 · 장소) | (Apple 저널 앱) | JournalingSuggestions(iOS 17.2) | 사용자가 고른 제안만 앱에 전달 | 중간. 엔타이틀먼트 필요. 응용 가치 불확실 |
| 메모 요약 · 사람/날짜 추출 | (Agenda · OmniFocus 등 일반 앱) | Foundation Models(iOS 26) | 기기 내 · 무료 · 오프라인. Apple Intelligence 기기 한정 | 중간. 선택 기능으로만 |
| NFC · QR 명함 교환 | (Wave Connect 등 디지털 명함) | Core NFC · `DataScannerViewController(.barcode)` | 카메라. 상대 쪽도 앱/QR 필요 | 작음(QR 읽기) — 활용도 낮음 |
| 위치 기반 알림 | (확인된 CRM 사례 없음) | Core Location 지역 감시 | 위치 "항상" 권한 — 매우 무거움 | 비추천 |

- 리멤버 초기의 "사람이 친다"는 방식은 정확도 대신 **명함 이미지가 회사로 간다**는 비용을 치렀다. 이 앱의 "기기 내 OCR → 후보 제안 → 사용자가 고름"은 같은 문제(오인식)를 **사용자 확인 단계로** 푸는 것이고, 이 방향이 개인정보 원칙과 맞는다.
- Dex · Clay의 핵심 경쟁력(외부 계정 동기화)은 이 앱이 따라 할 수 없다. 대신 "네트워크 0 · 자료는 기기에만"이 차별점이다.

### Gaps
- UpHabit · Cloze · Contacts+ · CamCard의 현재(2025–2026) 입력 기능을 1차 자료로 확인하지 못했다(검색 횟수 한도).
- 리멤버가 지금도 사람 검수를 하는지, OCR 인식률 수치는 공개 자료에서 찾지 못했다.
- Covve vs CamCard 정확도를 비교한 독립 시험은 없었다(벤더 보도자료뿐).
- Apple Watch · 대화형 알림 · iMessage 확장을 쓰는 개인 CRM 사례를 찾지 못했다.

## 2. 쓸 수 있는 iOS 플랫폼 기능과 그 개인정보 비용 (iOS 17+)

### Takeaway
iOS 17~26은 **권한을 묻지 않거나 아주 좁게 묻는** 입력 API를 계속 늘렸다 — 연락처 선택기, iOS 18 제한 연락처 접근 · `ContactAccessButton`, EventKit 쓰기 전용, 대화형 위젯(App Intents), 기기 내 `SpeechAnalyzer`(iOS 26), 기기 내 Foundation Models(iOS 26). 이 앱(iOS 17+)에서 당장 쓸 수 있는 것은 App Intents · 대화형 위젯 · 연락처 선택기 · EventKit이고, iOS 18/26 기능은 `if #available` 로 덧붙이는 선택 기능이다.

### Cited Findings
- **iOS 18 제한 연락처 접근:** 권한 창이 두 단계가 되어 "고른 연락처만" 또는 "전체"를 고르고, 나중에 늘릴 수 있다. 제한 모드에서도 연락처 만들기 · 고치기는 된다 — [WWDC24 Meet the Contact Access Button](https://developer.apple.com/videos/play/wwdc2024/10121/?time=0)
- **`ContactAccessButton`:** 앱 화면 안에 들어가 한 번 눌러 새 연락처 접근을 허용받는다. 연락처 접근 선택기는 앱을 떠나지 않고 보이는 연락처를 바꾼다 — [WWDC24 10121](https://developer.apple.com/videos/play/wwdc2024/10121/?time=93). 2024-09 포럼에서 제한 모드 중 전체 접근 요청이 무반응 · 버튼 XPC 오류로 앱 멈춤 보고(1건) — [Apple 개발자 포럼](https://origin-devforums.apple.com/forums/profile/adamtwo)
- **EventKit (iOS 17):** `requestFullAccessToEvents` / `requestWriteOnlyAccessToEvents` 로 나뉨. 쓰기 전용이면 일정 조회가 빈 결과. 쓰기 전용으로 충분하면 전체 접근을 요청하지 말라고 Apple이 권고. iOS 17부터 `NSCalendarsFullAccessUsageDescription` 등이 없으면 자동 거부 — [Apple: Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store.md). 시스템 `EKEventEditViewController` 만 띄우면 권한 불필요(2차 자료) — [tessl EventKit skill](https://tessl.io/registry/dpearson2699/swift-ios-skills/3.6.0/files/skills/eventkit/SKILL.md)
- **대화형 위젯 (iOS 17):** `Button` · `Toggle` 이 `AppIntent` 를 받아 위젯 안에서 동작. `perform()` 이 끝나면 위젯이 다시 그려짐. 위젯에서 되는 컨트롤은 이 둘뿐 — [WWDC23 Bring widgets to life 노트](https://wwdcnotes.com/notes/wwdc23/10028)
- **App Intents (iOS 17):** 인텐트를 위젯 확장 코드에 바로 선언, 같은 인텐트가 위젯 설정 · 단축어 동작을 겸함(`AppIntentConfiguration`) — [WWDC23 Explore enhancements to App Intents](https://developer.apple.com/wwdc23/10103)
- **VisionKit `DataScannerViewController`:** Live Text와 같은 언어를 쓰며 **한국어 · 일본어는 iOS 16에서 추가**. `.text(languages: ["ko"])` 로 지정 — [WWDC22 Capture machine-readable codes and text with VisionKit](https://developer.apple.com/wwdc22/10025). A12 이상 필요(2차 자료) — [ITNEXT](https://itnext.io/4-steps-to-ios-text-qr-code-recognition-ffb29d1d6c03). iOS 17 추가분은 글자 추적(optical flow) · 통화 인식 — [WWDC23 What's new in VisionKit 노트](https://wwdcnotes.com/notes/wwdc23/10048)
- **`SpeechAnalyzer` (iOS 26):** `SFSpeechRecognizer` 후속. 모듈 `SpeechTranscriber`(받아쓰기) · `SpeechDetector`(음성 구간). 시스템이 내려받아 관리하는 새 모델로 **기기 안에서** 동작, 회의 · 대화 같은 긴 · 먼 음성에 강함. watchOS 미지원 — [WWDC25 세션 277 색인](https://nonstrict.eu/wwdcindex/wwdc2025/277/); [addpipe 정리](https://blog.addpipe.com/apple-speechanalyzer-api/). 34분 영상에서 Whisper Large-v3 대비 55% 빨랐다는 개인 시험 — [GIGAZINE](https://www.gigazine.net/gsc_news/en/20250619-apple-speech-analyzer). 실시간 마이크에서 예제대로 하면 글자가 안 나오는 함정 보고 — [DEV](https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5)
- **Foundation Models (iOS 26):** Apple Intelligence의 기기 내 모델을 앱에 공개. 오프라인 · 요청당 비용 없음 · 무료. `LanguageModelSession`, `@Generable` · `@Guide` 로 구조화 출력(guided generation), 도구 호출 지원 — [9to5Mac](https://9to5mac.com/2025/09/29/apple-intelligence-ios-26-models-developers/); [ADTmag](https://adtmag.com/articles/2025/06/10/apple-launches-ondevice-ai-framework-and-tools.aspx). Apple Intelligence 지원 언어에 **한국어 포함** — [Cult of Mac](https://www.cultofmac.com/news/apple-foundation-models-framework). 기기: iPhone 15 Pro 이상, 모델 약 3GB(2차 자료) — [atelier-socle 가이드](https://www.atelier-socle.com/en/articles/foundation-models-api-guide)
- **JournalingSuggestions (iOS 17.2):** 시스템 선택기에서 "연락한 사람" 같은 순간을 보여 주고, **사용자가 명시적으로 고른 제안만** 앱에 전달. 앱이 SiriKit · CallKit에 상호작용을 기부하면 제안에 나타날 수 있음. 가로 모드 미지원 — [Apple 문서](https://developer.apple.com/documentation/journalingsuggestions.md); [Apple 뉴스룸](https://www.apple.com/newsroom/2023/12/apple-launches-journal-app-a-new-app-for-reflecting-on-everyday-moments)

### Inferences
- **권한 비용 순(가벼움 → 무거움):** 키보드 받아쓰기 · 연락처 선택기 · 위젯/App Intents · 공유 확장 · 저널 제안(0) < 카메라(명함) < 제한 연락처 < 마이크+음성 인식 < 캘린더 전체 읽기 < 위치 "항상". 이 앱 원칙에는 왼쪽 절반이 맞는다.
- 기기 안에서만 처리하고 밖으로 보내지 않으면 App Store 개인정보 라벨상 "수집"에 해당하지 않을 가능성이 높다(Apple 정의상 "수집"은 기기 밖 전송). 단 이 정의는 이번 조사에서 1차 출처로 확인하지 못했다 → Gaps.
- Foundation Models는 iPhone 15 Pro 이상 + Apple Intelligence 켬이 전제라 **필수 기능이 될 수 없다**. "기록 메모 → 한 줄 요약 · 사람 이름 · 날짜 후보" 같은 **제안형 선택 기능**이 적당하다. `@Generable` 출력도 Core 검증(`Validator`)을 거쳐야 한다.
- 캘린더 연동은 Dex의 대표 기능이지만 iOS에서는 **전체 캘린더 읽기** 권한이 든다. 쓰기 전용으로는 일정을 읽을 수 없어 "회의 기록 제안"에 쓸 수 없다.

### Gaps
- App Store 개인정보 라벨의 "수집" 정의 · "Data Not Collected" 조건을 Apple 원문으로 확인하지 못했다.
- `ContactAccessButton` 의 최소 iOS(18) 외 UIKit 대응 · 현재 버그 상태는 미확인.
- 한국어 `SpeechAnalyzer` 받아쓰기 정확도, 한국어 Foundation Models 품질을 잰 자료는 없었다.
- 키보드 받아쓰기(시스템)가 권한 없이 기기 안에서 처리되는지 Apple 1차 자료로 확인하지 못했다.

## 3. 신뢰성 · 자료 안전 — 동기화 · 백업 형식 · 중복 · 사용자 불만

### Takeaway
SwiftData + CloudKit 동기화에는 **유니크 제약 없음 · 관계 전부 옵셔널 · `.deny` 삭제 규칙 불가 · 변경 순서 비보장**이라는 공식 제약이 있다(이 저장소 ADR-0001이 이미 지킴). 사용자 불만 증거는 생각보다 적게 잡혔고, 잡힌 것은 **"여러 출처를 합치다 중복 · 뒤죽박죽", "가져오기 실패 · 연락처 누락", "앱에서 고친 게 원래 연락처로 안 돌아감", "영구 삭제 불가"** 유형이다.

### Cited Findings
- **SwiftData + CloudKit 공식 제약:** 유니크 제약 · 필수(비옵셔널) 관계를 지원하지 않음. iCloud가 관계 변경을 원자적으로 처리한다고 보장하지 않기 때문. CloudKit은 변경을 정해지지 않은 순서로 처리하므로 역관계를 명시하라. `.deny` 삭제 규칙 불가 — [Apple: Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices.md)
- **추가 규칙(2차):** 모든 속성은 옵셔널이거나 기본값이 있어야 하고, 어기면 첫 실행에 저장소가 열리지 않을 수 있음. 순서 있는 관계 불가 — [fatbobman](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/). 큰 바이너리는 외부 저장 — [Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud)
- **Clay 불만 — 병합 실패:** 50개 넘는 출처를 합쳐 연락처가 뒤죽박죽, 연동 출처를 지워도 그 출처가 만든 연락처가 남음. 창업자가 "의도한 동작이 아니다"라고 답함(2023, 3점) — [AppSumo 리뷰](https://appsumo.com/products/clay/reviews/glad-its-not-syncing-back-to-my-actual-261810/)
- **Clay 불만 — 가져오기 실패:** iMessage 가져오기 실패 · iPhone 연락처 누락, "버그 많음"(2025, 비공식 집계 사이트라 신뢰 낮음) — [justuseapp](https://justuseapp.com/en/app/1463073824/clay-contacts-crm/contact)
- **Clay 동작 설명:** iOS 연락처는 읽기 전용이라 Clay 변경이 폰으로 안 돌아감, 영구 삭제 옵션 없음 — [Clay FAQ](https://library.me.sh/hc/en-us/articles/6925346551835-How-does-Clay-affect-my-iOS-Contacts)
- **Monica 내보내기:** vCard 내보내기 · CardDAV(포크 문서), 전체 내보내기는 SQL 파일(포크 문서, JSON 아님). 공식 사이트는 v3(2026년 말 예정, 처음부터 재작성)에서 "내보낼 수 있다"고만 함 — [GitHub 포크](https://github.com/bitnovus/monica); [monicahq.com](https://monicahq.com/)
- **Monica 자체 호스팅:** 백업을 사용자가 책임 — [folk.app](https://www.folk.app/zh/articles/personal-crm)
- **구독 잠금:** Dex는 LinkedIn 동기화 등 핵심 기능이 유료(월 $12~20) — [dupple](https://dupple.com/reviews/dex); [Dex 블로그](https://getdex.com/blog/dex-vs-wave-connect/)

### Inferences
**(2) 신뢰성 · 개인정보 실천 목록 (불만 증거와 함께)**
1. **가져오기는 합치기 전에 보여 준다.** Clay의 "뒤죽박죽 병합 · 지워도 남음" 불만 → 가져오기마다 "새로 · 같은 사람 후보 · 건너뜀" 미리보기, 가져온 묶음 단위로 되돌리기. 같은 이름 판정은 Core에서(정답표).
2. **원본(연락처 앱)과의 관계를 분명히 말한다.** Clay의 "고친 게 안 돌아감" 혼란 → 이 앱은 "복사해 온다 · 연락처 앱은 바꾸지 않는다"를 가져오기 화면에 적는다.
3. **삭제는 진짜 삭제 + 확인.** Clay의 "영구 삭제 불가" → 이 앱은 이미 확인 후 삭제(CLAUDE.md 규칙). 전체 데이터 삭제 2단계 확인(요구사항 303행)도 유지.
4. **백업 형식은 열린 형식 둘.** 앱 전체는 `schemaVersion` 있는 JSON(이미 FR-018), 사람 단위 호환은 vCard(.vcf) 내보내기를 덧붙이면 다른 앱 이동이 쉽다(Monica · 연락처 앱이 vCard를 받는다). 구독 잠금 반대편의 신뢰 근거가 된다.
5. **동기화는 나중이어도 스키마는 지금 CloudKit 규칙대로.** 공식 제약(유니크 없음 · 관계 옵셔널 · `.deny` 불가 · 순서 비보장) → 이미 ADR-0001. 중복은 유니크 제약 대신 `uuid` 기준 병합 + 앱 단 중복 검사로 다룬다.
6. **자동 백업 알림.** 기기 내 저장의 최대 위험은 기기 분실 · 앱 삭제. iOS 백업 포함 사실 고지(요구사항 669행)에 더해, 마지막 내보내기 후 N일 지나면 설정에 조용히 표시하는 정도가 적당(추론).
7. **자체 호스팅 · 서버형의 백업 부담을 사용자에게 넘기지 않는다** — Monica 사례의 반대편.

### Gaps
- r/PersonalCRM · App Store 리뷰에서 Dex · Covve · UpHabit · Cloze의 **자료 유실 · 동기화 실패** 불만을 직접 찾지 못했다(검색 결과가 벤더 비교글 위주). "불만 증거가 적다"는 것은 증거 부족이지 문제가 없다는 뜻이 아니다.
- SwiftData + CloudKit 실제 동기화 실패율 · 충돌 처리 방식(마지막 쓰기 우선 여부)을 Apple 1차 자료로 확인하지 못했다.
- iOS 17.0~17.3 유니크 제약 회귀 주장은 저품질 출처라 채택하지 않았다.

## 4. 하루 10명 + 만남 기록을 가장 빠르게 해 줄 것 (이 앱에 대한 우선순위 제안)

### Takeaway
이미 있는 명함 OCR · 연락처 선택기 · 빠른 연속 등록 위에서, **권한 0 · 네트워크 0** 으로 가장 많이 줄이는 것은 ① 단축어/App Intents + 대화형 위젯으로 "앱 열기 → 추가" 단계 없애기 ② 명함 연속 촬영(한 번에 여러 장) ③ 기록 입력 중 키보드 받아쓰기 유도와 최근 참여자 칩이다. 캘린더 제안은 효과가 크지만 전체 캘린더 읽기 권한이라 **선택 기능(기본 꺼짐)** 으로, Foundation Models 요약은 iOS 26 · 일부 기기 한정 선택 기능으로 둔다.

### Cited Findings
- 대화형 위젯 버튼이 App Intent를 실행하고 같은 인텐트가 단축어 동작을 겸한다 — [WWDC23 10028 노트](https://wwdcnotes.com/notes/wwdc23/10028); [WWDC23 10103](https://developer.apple.com/wwdc23/10103)
- 연락처 선택기 · 제한 접근으로 권한을 좁게 유지 — [WWDC24 10121](https://developer.apple.com/videos/play/wwdc2024/10121/?time=0)
- 쓰기 전용으로 일정을 읽을 수 없어, 회의 제안에는 전체 접근이 필요 — [Apple: Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store.md)
- 명함 정확도를 Dex는 "미리 채우고 사용자가 고침"으로 처리 — [Dex card scanner](https://guidev3.getdex.com/workflows/card-scanner)
- `SpeechAnalyzer` 는 회의 · 대화 같은 긴 음성용, iOS 26 — [WWDC25 277](https://nonstrict.eu/wwdcindex/wwdc2025/277/)
- Foundation Models는 기기 내 · 무료 · 구조화 출력, iOS 26 · Apple Intelligence 기기 — [9to5Mac](https://9to5mac.com/2025/09/29/apple-intelligence-ios-26-models-developers/)

### Inferences
**(3) 우선순위 제안** (효과 ÷ (권한 비용 + 구현 노력) 순. 1~4는 iOS 17에서 바로, 권한 0)

| 순위 | 제안 | 줄이는 것 | API · 최소 iOS | 권한 | 노력 · 위험 |
|---|---|---|---|---|---|
| 1 | **App Intents: `사람 추가` · `기록 추가` · `명함 찍기` 단축어** + App Shortcuts(Siri 문구) · 동작 버튼 · 잠금 화면 | 앱 열고 화면 찾아가는 2~3번의 탭 | App Intents · iOS 17 | 없음 | 작음. 앱을 여는 인텐트(`openAppWhenRun`)부터 시작하면 저장소 공유 불필요 |
| 2 | **홈 화면 위젯: 단추 3개(사람 · 기록 · 명함)** + 오늘 추가한 사람 수 | 위와 같음 + "오늘 몇 명" 확인 | WidgetKit 대화형 위젯 · iOS 17 | 없음 | 중간. 숫자 표시는 App Group 저장소 필요 → 처음엔 앱 여는 링크 단추만 |
| 3 | **명함 연속 촬영** — 문서 카메라로 여러 장 → 장마다 후보 확인 큐 | 명함 10장을 10번 들어가 찍는 반복 | `VNDocumentCameraViewController`(여러 장 지원) · 기존 OCR | 카메라(이미 있음) | 작음~중간. 기존 FR-050 · FR-051 확장 |
| 4 | **기록 입력 속도:** 최근/오늘 만난 사람 칩, 마지막 기록 유형 · 장소 기억, 키보드 받아쓰기 안내 | 참여자 고르기 · 반복 칸 | SwiftUI 만 | 없음 | 작음. 정렬은 `NameSort` 재사용 |
| 5 | **가져오기 중복 미리보기 + vCard(.vcf) 열기/공유 받기** | 연락처 · 다른 앱에서 옮길 때 중복 정리 | `CNContactPicker`(여러 명) · UTType `.vcard` · 공유 확장 | 없음(선택기) | 중간. 중복 판정은 Core 정답표 |
| 6 | **캘린더 일정 → 기록 제안 (선택 기능, 기본 꺼짐)** — 끝난 일정의 참석자 이름을 사람과 맞춰 "기록할까요" | 회의 기록 시작점 · 날짜 · 참여자 입력 | EventKit 전체 접근 · iOS 17 | **캘린더 전체 읽기** | 중간~큼. 개인정보 안내 문구 · 거절 시 동작 필요 |
| 7 | **앱 안 음성 메모 → 글자** (기록 메모 칸) | 만남 직후 긴 메모 | `SpeechAnalyzer` iOS 26(`SFSpeechRecognizer` iOS 17 대체) | 마이크 + 음성 인식 | 중간. 한국어 품질 미검증 |
| 8 | **메모 요약 · 사람/날짜 후보 추출 (선택)** | 긴 메모 정리 | Foundation Models · iOS 26 · iPhone 15 Pro+ | 없음 | 중간. 제안만, 저장 전 사용자 확인 |
| 보류 | 저널 제안 · NFC/QR · 위치 알림 · 외부 계정 동기화 | — | — | 위치는 매우 무거움, 외부 동기화는 원칙 위반 | — |

- 하루 10명이 전제라면 병목은 "한 명 입력 시간"보다 **"입력을 시작하기까지의 단계"와 "명함 묶음 처리"** 일 가능성이 높다 → 1~3이 먼저.
- 1·2는 원격 세션에서 컴파일할 수 없는 새 타깃(위젯 확장)이 생기므로, CLAUDE.md 3절 규칙대로 **앱을 여는 인텐트 → 위젯 링크 단추 → 저장소 공유** 순으로 작게 나눠 CI에 올리는 편이 안전하다.
- 6·7·8은 권한 · iOS 버전 · 기기 제약이 있어 1.0 이후 사용자 선택지로 묻는 것이 맞다.

### Gaps
- 하루 10명 입력에서 단계별 소요 시간(앱 열기 · 명함 촬영 · 확인 · 기록)을 잰 자료는 없다 — 실기기 시간 로그(이 앱의 `LaunchTiming` 류)로 직접 재야 한다.
- 위젯 · 단축어가 개인 CRM 사용자의 입력 빈도를 실제로 올렸다는 외부 자료는 찾지 못했다.
