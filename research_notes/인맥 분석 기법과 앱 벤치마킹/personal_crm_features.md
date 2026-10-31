# 개인용 인맥 관리 앱(personal CRM) 기능 벤치마킹 — 2025~2026

> 조사일 2026-10-18. **조사 방법 한계:** 이 세션에서는 페이지 원문 가져오기(WebFetch)가 네트워크 정책으로 막혀(getdex.com · lemlist.com 등 `connect_rejected`), 모든 사실은 **웹 검색 결과 요약**에서 뽑았다. reddit.com 은 검색 도구가 접근을 거부해 Reddit 반응은 직접 확인하지 못했다. 출처 상당수가 **경쟁 앱이 쓴 비교 글**(Dex · kinu.care · Relatable · RareFriend · Wend 등)이므로 가격 · 날짜는 공식 페이지에서 다시 확인해야 한다. 상충하는 값은 상충한다고 적었다.

## 질문 1. 앱별 현재 상태 · 가격 · 핵심 기능

### Takeaway
시장은 (가) 자동 수집 · 보강형(Mesh=옛 Clay, Dex, Cloze, Contacts+, 리멤버)과 (나) 수기 기록 · 연락 주기형(Monica, Fabriq, Garden, Covve 일부)으로 나뉜다. 2025~2026 의 큰 변화는 **Clay → Mesh(Automattic 인수)**, **UpHabit 종료(2026-04-09)**, 그리고 거의 모든 유료 앱의 "AI 로 내 인맥에 묻기" 기능 추가다. 소비자용 앱 중 **관계망 그래프(누가 누구를 아는가)를 보여 주는 앱은 찾지 못했다** — 그래프는 기업용 영업 도구(Introhive · Rings AI)에만 있었다.

### Cited Findings

#### 앱별 요약표

| 앱 | 상태 (2026) | 가격 | 핵심 객체 · 기능 | 연락 주기 · 생일 | 관계 지표 · 점수 | AI | 연동 · 플랫폼 |
|---|---|---|---|---|---|---|---|
| **Mesh (옛 Clay)** | 활동 중. Automattic 인수 후 Mesh 로 개명, clay.earth → me.sh 301 이동 | 무료(최근 1,000명 검색) · Pro 월 $10(연간) · 팀 $40~49/석(출처 상충) | 사람 · 메모 · 그룹 · 자동 보강(경력 · 최근 글) | 생일 · 기념일 알림, 재연락 주기 | "식어 가는" 사람 표시(단일 출처) | Nexus — "○○회사에 아는 사람?" 자연어 질의, 요약 · 후속 메시지 초안(조기 접근) | 메일 · 캘린더 · LinkedIn · iMessage · WhatsApp · X. iOS · 웹 · 2026-08 Android |
| **Dex** | 활동 중 | Premium 월 $12(연간)~$20, Professional $20~34 (출처 상충) | 사람 · 메모 · 연락 기록 · 리마인더 | 연락 주기 리마인더(호평) | 확인 못 함 | 회사 주장: 메일 · 캘린더 · 메모 맥락 요약, 연락 제안. 제3자: "깊은 AI 없음(2026 초)" | LinkedIn 동기화(직장 변경 알림) · Gmail · Outlook · 폰 연락처 · 크롬 확장. 모바일 · 데스크톱 |
| **Monica** | 활동 중(오픈소스). 판 번호 출처 상충(v4.1.2 / v5.0.0-beta.5 2025-04) | 자체 호스팅 무료, 호스팅 월 약 $9 | 사람 · 활동 · 대화 · 인생 사건 · 선물 · 빚 · 약속 · 일기 · 할 일 · 여러 금고(vault) | 생일 자동 리마인더, 이메일 알림 | **순위 매기지 않음을 명시** | 없음 | CardDAV/CalDAV. 메일 · LinkedIn 연동 없음, 전부 수기 |
| **UpHabit** | **2026-04-09 종료**, 스토어 목록 사라짐(일부는 "설치본은 동작" 주장) | — | 사람 · 메모 · 리마인더 · 연락 추적 | 리마인더 | — | — | 종료 공지가 "설정 → Export All Contacts" 안내 |
| **Covve** | 활동 중 | 무료(20명 한도) · Pro 월 $12.99 / 연간 시 $9.99 (다른 집계는 $5) | 명함 스캔 · 사람 · 연락 후 메모 | 리마인더("소음이 되지 않음" 호평) | — | 연락처 관련 뉴스 큐레이션 | 앱 내 통화 · 문자 기록. 모바일 중심 |
| **folk** | 활동 중(소규모 팀 CRM 쪽으로) | 무료 없음, Standard $24/석(연간) · Premium $48 · Enterprise $80~ | 연락처 · 파이프라인 · 이메일 시퀀스 · 대시보드 | — | 구매 신호(이직 등) 추적 없음 | AI 어시스턴트 · Magic Fields | 2026-07 모바일 앱 출시 보도. G2 4.5 |
| **Cloze** | 활동 중(영업 · 부동산 쪽) | Pro 월 $17(연간)~$19.99, 상위 $21~42/사용자. 무료 존재 여부 출처 상충 | 메일 · 통화 자동 기록 | 아침 "연락할 사람" 목록(AI agenda) | **초기에 휴면도 · 빈도 · 응답성으로 점수화**, "losing touch" 묶음을 "keep in touch" 로 개명 | 식어 가는 관계 표시 | 메일 · 캘린더 · 전화 |
| **Garden** | 사실상 정체(최근 갱신 2019 무렵 기록, "수년간 업데이트 없음") | 프리미엄(freemium) | 사람 · 메모 · 태그 | 사람마다 매일~매월 주기, Reminder Auto-Pilot | — | — | iPhone 전용 |
| **Nat** | 휴면 추정(사이트 2025 초부터 그대로, 연 $370 판매 중) | 연 $370 | 데이터로 "연락이 끊기는 사람" 자동 판단 | — | 자동 판단 | — | 확인 못 함 |
| **Contacts+ (Plus)** | 활동 중(웹 앱 재설계) | 무료(1,000명 · 계정 1개) · Premium 월 $13.99 / 연간 $9.99~ (출처 상충) · Teams 월 $12.99/인 | 주소록 동기화 · 명함 스캔(월 100장) · 자동 보강 | — | — | — | 여러 계정 동기화. iOS · 웹 |
| **Fabriq** | 활동 중(한동안 조용하다 2026-06 iOS 2.4.6, 2026-07 Android 갱신). 일부 디렉터리가 "중단"으로 잘못 표기 | 확인 못 함 | **던바 수 기반 원(circle)**: 가까운 원 + 약 100명 확장 원, 최대 150명 | 초록→빨강으로 줄어드는 고리 리마인더 | 고리 색이 사실상 "상태 표시" | — | 모바일 전용, 데스크톱 · 암호화 동기화 없음, 정식 내보내기 없음 |
| **Queue** | 상태 미확인(옛 iOS 베타 기록뿐) | — | — | — | — | — | — |
| **리멤버 (Remember)** | 활동 중, 채용 플랫폼 비중 커짐(스카우트 제안 800만→1,000만 건, 2025) | 개인 무료(보관 무제한) · 팀 월 5,500원/인(연간) | 명함 촬영 → OCR + **사람 검수** | — | — | — | 인맥의 승진 · 이직 알림, 폰 주소록 · 구글 연락처 동기화, 엑셀 내보내기 |
| **Apple Journal** | iOS 17~, iOS 26 에서 iPad · Mac 확장 | 무료 | 일기 | — | — | 기기 내 "일기 제안"(연락처: 자주 메시지 · 통화한 사람 포함) | 제안은 기기에서 생성. 특정 사람 제외 설정은 문서화 안 됨 |

#### 출처별 세부
- Clay 의 개인 CRM 은 Mesh 로 이름이 바뀌었고 같은 제품이다. 개명 시점은 2024 · 2025 · 2026-03 으로 출처가 엇갈린다. 2026-09 확인에서 clay.earth 가 me.sh 로 301 이동하며 쿼리 문자열을 버린다 — [Wend](https://www.trywend.io/blog/what-happened-to-clay-crm); [Dex: Mesh review](https://getdex.com/blog/mesh-review/); [use-apify](https://use-apify.com/blog/clay-personal-crm-review-2026)
- Clay.com(영업 GTM 도구)은 별개 회사다 — [use-apify: Apify vs Clay](https://use-apify.com/docs/apify-vs-the-world/apify-vs-clay)
- Automattic 이 2025-06 Clay 를 인수했다는 서술, 무료 Personal(최근 1,000명) · Pro 월 $10(연간), 팀 $49 또는 $40/석(상충), 14일 Pro 체험 — [OnePageCRM](https://www.onepagecrm.com/blog/best-personal-crm/); [Dex: Mesh review](https://getdex.com/blog/mesh-review/)
- Mesh Nexus AI 는 조기 접근, "특정 회사 · 도시에 누구를 아는가" 질의. 음성 · 개선된 명함 스캔 실험 중. Android 판 출시 — [TechCrunch 2026-08-12](https://techcrunch.com/2026/08/12/mesh-automattics-crm-for-everyone-comes-to-android/); [App Store: Mesh](https://apps.apple.com/us/app/mesh-contacts-crm/id1463073824)
- Mesh 모바일 신뢰성 문제(메모가 모바일에 동기화 안 됨, 개별 연락처에서 Nexus 오작동), 앱스토어 결제 환불 불가 사례 — [Dex: Mesh review](https://getdex.com/blog/mesh-review/)
- Clay 기능: 생일 · 기념일 리마인더, 재연락 주기, 그룹(북클럽 · 고교 친구), 어디서 만났는지 · 자녀 이름 메모, 위치 · 메모 · 마지막 만남으로 자연어 검색, 메일 · 캘린더 · LinkedIn · iMessage · WhatsApp · X 에서 수집 — [Geekflare](https://geekflare.com/software/clay-review/); [AppSumo](https://appsumo.com/products/clay/?p=1&pt=q)
- Dex: LinkedIn · 메일 · 캘린더 · 연락처 수집, 크롬 확장 한 번 클릭 추가, 직함 변경 자동 동기화. 가격 $12(연간)~$20 / $20~34 상충, 체험 7일 또는 14일 상충. 리마인더 엔진 "성숙하고 시기가 맞다" — [Capterra](https://www.capterra.com/p/275020/Dex/); [Software Advice](https://www.softwareadvice.com/crm/dex-profile/); [coldiq](https://coldiq.com/tools/dex); [storyflow](https://storyflow.so/blog/best-personal-crm-tools-2026)
- Dex AI: 회사 블로그는 메일 · 캘린더 · 메모 맥락 요약과 연락 제안을 주장, 제3자 집계는 "깊은 AI 없음(2026 초)" — [Dex vs Cloze](https://getdex.com/blog/dex-vs-cloze/); [storyflow](https://storyflow.so/blog/best-personal-crm-tools-2026)
- Dex 리뷰어 요청: macOS 메일 · Apple 메시지 연동 — [Capterra](https://www.capterra.com/p/275020/Dex/reviews/)
- Monica: 삶의 근황, 어떻게 아는 사이인지, 중요한 날, 지난 대화, 선물 · 빚 · 약속, 재연락 리마인더, 일기, 여러 금고, CardDAV/CalDAV. 메일 · 캘린더 · LinkedIn 연동과 자동 가져오기 없음 — [Monica 공식](https://www.monicahq.com/en/); [dench.com 리뷰](https://www.dench.com/blog/monica-crm-review); [itsfoss](https://itsfoss.com/monica/)
- Monica 판 번호 상충(공식 홈 "v3 연내" 문구 · 디렉터리 v4.1.2 · 변경 기록 v5.0.0-beta.5 2025-04-21) — [Monica 공식](https://www.monicahq.com/en/); [ossroster](https://ossroster.com/tools/monica)
- UpHabit 2026-04-09 종료, 8년 넘게 운영, "제품은 성공했으나 상업적 성공 실패", 내보내기 안내 — [kinu.care](https://kinu.care/blog/uphabit-alternatives); [kinu.care 종료 목록](https://kinu.care/blog/personal-crm-apps-shut-down); [Gravity](https://mygravity.app/compare/uphabit)
- Fabriq 은 종료되지 않았다(2026-07-20 Android 갱신). Nat 은 휴면(사이트 2025 초부터 불변, 연 $370). Keep My Friends 가입 중단(2023-07~). Garden · Amicu 수년간 무갱신. Sunshine Contacts(~2022 우선순위 하락) · Monaru 종료(확인 필요) — [kinu.care 종료 목록](https://kinu.care/blog/personal-crm-apps-shut-down); [kinu.care Fabriq](https://kinu.care/blog/fabriq-alternatives)
- Covve: 무료 20명, Pro 월 $12.99 / 연간 $9.99, 명함 스캐너 빠름, 뉴스 엔진, 리마인더가 소음이 되지 않음. "스캐너 중심, 일상 CRM 으로는 약함" — [crm.org Covve](https://crm.org/news/covve-review); [Dex: Covve review](https://getdex.com/blog/covve-review/); [softwaresuggest](https://www.softwaresuggest.com/covve)
- folk: 무료 없음 14일 체험, Standard $24 · Premium $48 · Enterprise $80~(연간), 파이프라인 · 시퀀스 · 대시보드는 Premium, AI 어시스턴트 · Magic Fields, G2 4.5, 이직 신호 없음, 2026-07 모바일 앱 — [folk 자체 리뷰 글](https://www.folk.app/articles/folk-reviews-what-do-people-really-think-of-our-crm-and-the-alternatives); [syncgtm](https://syncgtm.com/blog/folk-crm-review); [marketintelligencetools](https://marketintelligencetools.com/reviews/folk-crm/)
- Cloze: 아침 연락 목록(단계 · 세그먼트별 시기), 식어 가는 관계 표시. 가격 Pro $17(연간)/$19.99, 상위 $21 · $29 · $42. 무료판 여부 상충 — [Dex: Cloze review](https://getdex.com/blog/cloze-crm-review/); [fitgap](https://us.fitgap.com/products/000125/cloze); [tomba](https://tomba.io/blog/cloze-pricing-reviews-pros-and-cons); [Capterra](https://www.capterra.com/p/186061/Cloze/)
- Garden: 사람마다 매일~매월 주기, 메모 · 태그, iPhone 전용, 2019 판에서 Contact Search · Reminder Auto-Pilot · 주기 맞춤 추가 — [App Store: Garden](https://apps.apple.com/us/app/garden-stay-in-touch/id1230466454); [Product Hunt](https://www.producthunt.com/products/garden); [TechCrunch 2018](https://techcrunch.com/2018/04/10/a-new-app-called-garden-helps-you-stay-in-touch-with-friends-and-family-without-facebook/)
- Nat: 데이터로 "연락이 끊기는 사람"을 자동으로 찾아 준다는 소개(CEO · 창업자 · 컨설턴트 대상) — [AlternativeTo: Dex 대안](https://alternativeto.net/software/dex/?p=2)
- Contacts+: Premium 명함 스캔 월 100장, 계정 5개 실시간 동기화, 자동 보강. Premium 월 $13.99 · 연간 월 $9.99 또는 연 $99.99(상충), 무료 1,000명, Teams 월 $12.99/인, 명함 100장 묶음 $17.99 앱 내 구매 — [Contacts+ Premium](https://contactsplus.com/premium/); [Contacts+ 가격](https://www.contactsplus.com/pricing/); [App Store](https://apps.apple.com/app/id579616837); [GetApp](https://www.getapp.com/all-software/a/contacts-1/)
- Fabriq: 던바 기반 원, 가까운 원 + 약 100명 확장 원, 최대 150명, 초록→빨강 고리, 고정된 원 이름(사용자는 "북클럽" 같은 맞춤 이름 · "지인" 단계 요청) — [Fabriq 공식](https://ourfabriq.com/fabriq); [Google Play](https://play.google.com/store/apps/details?id=com.ourfabriq&hl=en_US); [kinu.care](https://kinu.care/blog/friendship-tracker-apps)
- 리멤버: OCR 후 사람 검수(초기 약 1,000명 타이피스트, 99% 이상 주장 — 검증 안 된 수치), 승진 · 이직 알림, 주소록 · 구글 연락처 동기화, 엑셀 내보내기, 개인 무료 · 팀 월 5,500원/인, 한 장씩 촬영이 기본(일괄 처리 약함), 타이피스트 입력 단계에 대한 개인정보 우려 — [나무위키](https://namu.wiki/w/%EB%A6%AC%EB%A9%A4%EB%B2%84(%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98)); [Lido](https://www.lido.app/kr/myeongham-ocr); [디지털투데이](https://www.digitaltoday.co.kr/news/articleView.html?idxno=69803); [App Store 리멤버](https://apps.apple.com/KR/app/id840553277); [더피알](https://www.the-pr.co.kr/news/articleView.html?idxno=53965)
- Apple Journal: iOS 26 에서 iPad · Mac 로 확장, 제안 범주에 "연락처: 메시지 · 통화하는 사람", 기기 내 생성, 설정 → 개인정보 보호 및 보안 → 일기 제안에서 범주별 끄기, 사람별 제외는 문서화 안 됨 — [9to5Mac](https://9to5mac.com/2026/01/05/ipados-26-adds-new-journal-app-and-ive-been-using-it-almost-every-day/); [Apple 지원](https://support.apple.com/en-al/guide/iphone/iph9824e83ce/ios); [journalinginsights](https://journalinginsights.com/journaling-suggestions-on-iphone/); [PolitiFact](https://politifact.com/factchecks/2024/mar/04/facebook-posts/write-this-down-apples-journal-app-isnt-telling-pe/)
- 관계망 그래프 검색 결과는 기업용뿐: Introhive(관계 강도 색 · "누가 누구를 아는가" 소개 경로), Rings AI(팀 메일 · LinkedIn 분석으로 모든 연락처에 관계 강도 점수 + 그래프), Dynamics 365 Map My Relationships, Gephi — [Introhive](https://www.introhive.com/blog-posts/what-is-relationship-mapping-and-how-does-it-work/); [Rings AI](https://www.rings.ai/blog/best-network-mapping-software); [Inogic](https://docs.inogic.com/map-my-relationships)
- 기기 내 저장을 내세운 소규모 앱: Intriq(로컬 우선 · 스크래핑 없음 · 내보내기/삭제 통제, iPhone), Contact Journal(폰에만 저장 · 인터넷 불필요), EvergreenCRM(Mac, 로컬 SQLite), Dextr(기기 처리 · 암호화 iCloud 백업 주장) — [Intriq](https://www.intriq.app/personal-crm/); [App Store: Contact Journal](https://apps.apple.com/us/app/id1186696582); [App Store: EvergreenCRM](https://apps.apple.com/us/app/evergreencrm/id6753191506?mt=12); [Dextr](https://dextr.app/articles/best-personal-crm-apps-in-2026/)
- 리뷰어 추천 요약: "자동이면 Mesh, LinkedIn 이면 Dex, 내 데이터 소유면 Monica, 직접 만드는 걸 좋아하면 Notion" — [lemlist](https://www.lemlist.com/blog/personal-crm)

### Inferences
- **"어떻게 알게 되었나 · 소개자"를 구조화된 칸으로 가진 앱은 확인되지 않았다.** Monica("how you know them")와 Clay(메모에 어디서 만났는지)가 가장 가깝지만 자유 메모 수준으로 보인다. 느린 인연의 첫 인연 · 소개자 모델은 차별점일 가능성이 크다(원문 확인 못 함 — 갭 참조).
- **여러 참여자가 공유하는 기록(N:M)** 을 명시한 소비자 앱도 확인하지 못했다. 대부분 "연락처 1명 ↔ 상호작용"이다.
- 소비자 personal CRM 에 **관계망 그래프 · 군집 찾기 · 시간 막대** 는 사실상 없다. 그래프 + 점수는 기업용 영업 도구의 언어다. 느린 인연의 관계도는 시장에서 드문 기능이다.
- 시장 생존 신호: UpHabit("제품은 성공, 상업은 실패") · Monaru · Garden 정체 · Nat 휴면 — 소비자 대상 구독은 지속이 어렵다. 이는 서버 비용이 없는 기기 내 앱 구조의 장점이다.
- 앱 종료 때 사용자가 가장 먼저 찾는 것이 **내보내기**였다(UpHabit 공지 · Fabriq "정식 내보내기 없음" 비판). JSON 백업은 그 자체로 신뢰 요소다.

### Gaps
- 공식 페이지 원문(가격표 · 도움말 · 변경 기록)을 하나도 직접 읽지 못했다 — 페이지 가져오기 차단. 가격은 전부 2차 출처.
- Queue 의 현재 상태, Nat 의 기능 상세, Fabriq 가격은 찾지 못했다.
- Notion 템플릿은 "직접 만드는 사람용"이라는 언급 외 주목할 만한 템플릿을 확인 못 했다.
- Apple 연락처 앱의 관계 라벨 · 메모 관련 2025~2026 변경은 검색 결과가 없었다.
- 아시아 앱 중 캠카드(CamCard) · 비즈리더는 비교 기사 제목에만 보였고 2025~2026 기능은 확인 못 했다.

## 질문 2. 리뷰에서 칭찬받는 것 vs 불평받는 것

### Takeaway
칭찬은 **설정이 쉽고 입력이 거의 자동인 것**(LinkedIn 동기화 · 직장 변경 알림 · 빠른 명함 스캔)과 **소음이 되지 않는 리마인더**에 모인다. 불평은 **수기 입력 부담**, **쌓여서 죄책감이 되는 리마인더**, **관계를 영업 파이프라인처럼 다루는 느낌**, **모바일 동기화 불안정 · 내보내기 부재 · 종료 위험**이다.

### Cited Findings
- 칭찬: Dex 의 쉬운 설정과 LinkedIn 연동, 리마인더 엔진의 시기 — [coldiq](https://coldiq.com/tools/dex); [storyflow](https://storyflow.so/blog/best-personal-crm-tools-2026)
- 불평: Dex 는 LinkedIn API 안정성에 의존 — [coldiq](https://coldiq.com/tools/dex)
- 칭찬: Covve 의 빠른 명함 스캐너, 소음이 되지 않는 리마인더 — [crm.org](https://crm.org/news/covve-review)
- 칭찬: folk 의 단순함 · 약 20분 설정(G2 4.5) — [syncgtm](https://syncgtm.com/blog/folk-crm-review)
- 불평: Monica 는 인터페이스가 낡았고 모든 연락처 · 상호작용을 손으로 넣어야 한다 — [dench.com](https://www.dench.com/blog/monica-crm-review); [wavecnct](https://wavecnct.com/blogs/the-6-best-personal-crm-tools-in-2025)
- 불평: Mesh 의 모바일 메모 동기화 실패 · 환불 불가 — [Dex: Mesh review](https://getdex.com/blog/mesh-review/) (경쟁사 글)
- 불평: Fabriq 의 고정된 원 이름, 맞춤 원 · "지인" 단계 요청, 정식 내보내기 없음 — [Google Play](https://play.google.com/store/apps/details?id=com.ourfabriq&hl=en_US); [kinu.care](https://kinu.care/blog/fabriq-alternatives)
- 불평: 리멤버의 일괄 처리 약함, 사람 검수 단계의 개인정보 우려 — [Lido](https://www.lido.app/kr/myeongham-ocr); [디지털투데이](https://www.digitaltoday.co.kr/news/articleView.html?idxno=69803)
- 리마인더가 몇 달이면 "죄책감 어항(guilt aquarium)"이 된다 — 너무 모호하고 잦고 관계와 동떨어져서 — [Relatable](https://www.bemorerelatable.com/blog/personal-crm-follow-up-reminders-that-work)
- 영업 파이프라인 논리는 사람 관계에 맞지 않는다 — 관계에는 단계 · 마감 대신 리듬 · 역사 · 맥락이 있고, 억지로 넣으면 거래처럼 납작해진다. 잦은 알림은 사용자가 무시하게 만든다 — [Goodword](https://www.goodword.com/blog/why-personal-crms-exist-and-what-most-of-them-get-wrong)
- 리마인더는 긴급함보다 의도를 받쳐야 진정성이 유지된다 — [Vtiger](https://www.vtiger.com/blog/what-is-personal-crm/)
- personal CRM 은 친한 친구보다 업무 · 느슨한 관계에서 시작된 실리콘밸리식 범주 — [Axios 2019](https://www.axios.com/2019/08/27/startups-new-frontier-optimizing-your-friendships)
- 앱스토어 결제가 웹 가격과 다를 수 있음 — [Dex: Mesh review](https://getdex.com/blog/mesh-review/)

### Inferences
- 느린 인연은 자동 수집을 하지 않으므로 Monica 와 같은 "수기 입력 부담" 비판을 받을 위험이 가장 크다. 명함 OCR · 연락처 가져오기 · 입력 상태 안내는 이 부담을 줄이는 쪽으로 이미 맞게 가 있다. 다음 단계는 "기록 1건을 몇 초 안에" 같은 입력 속도.
- "죄책감 어항" 비판은 연락 주기 리마인더를 넣을 경우의 설계 경고다 — 기본 끔, 사람이 고른 소수에게만, 밀린 것을 빨간 숫자로 쌓지 않기.

### Gaps
- Reddit(r/PersonalCRM)과 Product Hunt 댓글 원문은 접근 차단으로 직접 읽지 못했다. App Store 별점 · 리뷰 수도 수집하지 못했다.

## 질문 3. "관계 건강"을 어떻게 다루나 — 점수화와 그 반응

### Takeaway
점수 · 색 신호는 주로 **영업 · 자동 수집형**(Cloze 의 휴면도 · 빈도 · 응답성 점수, Rings AI · Introhive 의 관계 강도, Nat 의 자동 "끊기는 사람")에 있고, 친구용 앱은 **사람이 아니라 '연락한 지 얼마나'를 색으로**(Fabriq 고리 초록→빨강) 보여 준다. 점수를 **명시적으로 거부한 앱은 Monica** 뿐이었다("관계를 순위 매기지 않는다"). Cloze 가 "losing touch" 를 "keep in touch" 로 바꾼 것은 부정적 꼬리표에 대한 반발을 시사한다.

### Cited Findings
- Cloze 초기판은 휴면도 · 빈도 · 응답성으로 연락처를 점수화했고, "losing touch" 묶음을 나중에 "keep in touch" 로 개명 — [crm.org](https://crm.org/news/cloze-smart-contact-sorting-for-personal-and-pro-use)
- Cloze 점수는 상호작용 빈도 기반 — [TouchBase](https://touchbase.site/compare/cloze-personal-crm-vs-touchbase)
- Cloze 는 식어 가는 관계를 표시 — [Dex: Cloze review](https://getdex.com/blog/cloze-crm-review/)
- Mesh(Clay)도 "식어 가는" 사람을 띄운다(단일 출처, 확인 필요) — [use-apify](https://use-apify.com/blog/clay-personal-crm-review-2026)
- Rings AI 는 팀 메일 · LinkedIn 을 분석해 모든 연락처에 관계 강도 점수를 매기고 그래프로 보여 준다 — [Rings AI](https://www.rings.ai/blog/best-network-mapping-software)
- Introhive 는 관계 강도로 색을 칠하고 소개 경로를 강조 — [Introhive](https://www.introhive.com/blog-posts/what-is-relationship-mapping-and-how-does-it-work/)
- Nat 은 데이터로 누구와 멀어지는지 자동 판단 — [AlternativeTo](https://alternativeto.net/software/dex/?p=2)
- Fabriq 은 초록→빨강으로 줄어드는 고리로 "체크인할 때"를 알린다 — [Fabriq 공식](https://ourfabriq.com/fabriq); [kinu.care](https://kinu.care/blog/friendship-tracker-apps)
- Monica 는 친구 추천 · 관계 순위 · 광고 · 열람 알림을 하지 않는다고 밝힌다 — [Monica 공식](https://www.monicahq.com/en/); [wavecnct](https://wavecnct.com/blogs/the-6-best-personal-crm-tools-in-2025)
- 친구 관계를 "최적화"하는 스타트업 흐름에 대한 비판적 보도 — [Axios](https://www.axios.com/2019/08/27/startups-new-frontier-optimizing-your-friendships)

### Inferences
- 느린 인연의 원칙(ADR-0004: 사람을 점수화하지 않고 "내가 어떻게 돌보는가"에만 답함)은 시장에서 Monica 와 같은 쪽이며, 표현은 Fabriq 의 "연락 경과 시간"(사람의 가치가 아니라 나의 행동)과 가깝다. Cloze 의 개명 사례는 "끊기는 사람" 같은 꼬리표를 피하라는 근거로 쓸 수 있다.
- 기업용 그래프 도구가 그래프와 강도 점수를 묶어 파는 것과 달리, 느린 인연은 그래프를 점수 없이(군집 · 시간 변화만) 보여 주는 드문 조합이다.

### Gaps
- 점수가 "섬뜩하다(creepy)"는 사용자의 직접 발언(Reddit · 앱스토어 리뷰)은 찾지 못했다. Cloze 개명의 공식 이유도 확인 못 했다.

## 질문 4. 들여올 만한 기능 아이디어 (느린 인연 적합도 평가)

### Takeaway
기기 내 · 점수 없음 원칙과 잘 맞는 상위 후보는 ① 사람이 고른 소수에게만 거는 부드러운 연락 주기(기본 끔), ② 생일 · 기념일 · "알게 된 지 n년" 알림(로컬 알림), ③ 인생 사건 · 선물 · 약속 같은 Monica 식 기록 칸, ④ 원(circle) · 그룹 맞춤 이름, ⑤ 기기 내 자연어 검색(메모 · 장소 · 마지막 만남), ⑥ 명함 일괄 스캔, ⑦ vCard/CSV 내보내기. 자동 보강 · LinkedIn · 클라우드 AI 는 원칙과 충돌한다.

### Cited Findings
아이디어별 (보유 앱 · 반응 · 적합도). 근거 출처는 위 질문 1~3 의 해당 줄.

1. **연락 주기 리마인더(사람마다 주기)** — Dex · Mesh · Garden(매일~매월) · Fabriq(고리) · Monica · Covve · Reach(주 · 격주 · 월 · 분기). 반응: 가장 칭찬받는 기능이면서("성숙하고 시기 맞음", "소음이 되지 않음") 가장 큰 불평의 원천("죄책감 어항"). 적합도: **중상** — 로컬 알림으로 가능. 단 기본 끔, 사람이 직접 고른 사람만, 밀린 개수를 쌓지 않는 문구 필요 — [Reach App Store](https://apps.apple.com/us/app/-/id6757639785); [Relatable](https://www.bemorerelatable.com/blog/personal-crm-follow-up-reminders-that-work); [crm.org Covve](https://crm.org/news/covve-review)
2. **생일 · 기념일 알림** — Monica(생일 자동 리마인더) · Mesh/Clay · Contacts 계열. 반응: 기본 기능으로 당연시. 적합도: **상** — 기기 내 로컬 알림, 점수와 무관. 느린 인연 고유 변형: "알게 된 지 n주년"(첫 인연 날짜 활용) — [Monica](https://www.monicahq.com/en/); [AppSumo Clay](https://appsumo.com/products/clay/?p=1&pt=q)
3. **인생 사건 · 선물 · 빚 · 약속 기록** — Monica. 반응: 기능 폭 칭찬, 입력 부담 비판. 적합도: **상** — 기록 유형 · 태그로 흡수 가능(새 객체 대신 기록 유형 추가 검토) — [Monica](https://www.monicahq.com/en/); [dench.com](https://www.dench.com/blog/monica-crm-review)
4. **원(circle) · 친밀도 단계** — Fabriq(던바 150, 고정 이름). 반응: 맞춤 이름 · "지인" 단계 요청. 적합도: **중** — 점수가 아니라 사용자가 붙이는 꼬리표라면 OK. 이미 있는 관계 유형 · 태그와 겹치는지 먼저 확인 — [Google Play Fabriq](https://play.google.com/store/apps/details?id=com.ourfabriq&hl=en_US)
5. **그룹(북클럽 · 고교 친구) 단위 모임 정리** — Mesh/Clay. 적합도: **상** — 느린 인연의 군집 찾기 결과를 사용자가 이름 붙여 그룹으로 저장하는 흐름과 연결 가능 — [AppSumo Clay](https://appsumo.com/products/clay/?p=1&pt=q)
6. **자연어 · 전체 검색(위치 · 메모 · 마지막 만남)** — Mesh(Nexus AI, 클라우드) · Clay 검색. 적합도: **중** — 클라우드 LLM 은 불가, 기기 내 검색(필드 조건: "서울 · 작년 · 소개자 ○○")은 가능 — [TechCrunch](https://techcrunch.com/2026/08/12/mesh-automattics-crm-for-everyone-comes-to-android/); [Geekflare](https://geekflare.com/software/clay-review/)
7. **기기 내 AI 요약 · 질의** — Mesh Nexus · Dex(주장) · folk AI · Apple Journal 제안(기기 내). 반응: 기대 크나 신뢰성 불만(Nexus 오작동). 적합도: **하~중** — 네트워크 요청 금지 원칙상 기기 내 모델만 가능. 당장은 비추천 — [Dex: Mesh review](https://getdex.com/blog/mesh-review/); [Apple 지원](https://support.apple.com/en-al/guide/iphone/iph9824e83ce/ios)
8. **명함 스캔(일괄 · 정확도)** — Covve(빠름) · Contacts+(월 100장 한도) · 리멤버(사람 검수, 한 장씩). 반응: 속도 칭찬, 리멤버는 사람 검수에 개인정보 우려. 적합도: **상(이미 있음)** — 기기 내 OCR 이 리멤버 대비 개인정보 장점. 개선 후보: 여러 장 연속 촬영 — [crm.org](https://crm.org/news/covve-review); [Contacts+](https://contactsplus.com/premium/); [디지털투데이](https://www.digitaltoday.co.kr/news/articleView.html?idxno=69803)
9. **직장 · 직함 변경 알림 · 자동 보강** — Dex(LinkedIn) · 리멤버(승진 · 이직) · Mesh · Contacts+ · Covve(뉴스). 반응: 핵심 칭찬 요인. 적합도: **불가** — 외부 데이터 · 네트워크 필요. 대체: 사람의 소속 변경 이력을 사용자가 기록(소속 시점 기록) — [coldiq](https://coldiq.com/tools/dex); [나무위키 리멤버](https://namu.wiki/w/%EB%A6%AC%EB%A9%A4%EB%B2%84(%EC%95%A0%ED%94%8C%EB%A6%AC%EC%BC%80%EC%9D%B4%EC%85%98))
10. **메일 · 캘린더 · 메시지 자동 기록** — Cloze · Mesh · Dex · Covve(앱 내 통화 · 문자). 적합도: **하~중** — 메일 · 메신저는 불가. 단 기기 내 EventKit 캘린더 읽기로 "지난 일정에서 기록 만들기" 제안은 네트워크 없이 가능(권한 필요) — [Dex: Cloze review](https://getdex.com/blog/cloze-crm-review/); [Geekflare](https://geekflare.com/software/clay-review/)
11. **연락 후 메모 유도** — Covve(상호작용 뒤 메모 요청). 적합도: **중** — iOS 에서 통화 감지는 제한적. 대신 기록 저장 직후 "같이 있던 사람 추가?" 같은 흐름 — [lemlist](https://www.lemlist.com/blog/personal-crm)
12. **내보내기 · 이식성(vCard/CSV/JSON)** — UpHabit(종료 시 내보내기 안내) · 리멤버(엑셀) · Monica(CardDAV) · Intriq(내보내기/삭제 통제). Fabriq 은 없음으로 비판. 적합도: **상** — JSON 백업 위에 vCard 내보내기 추가는 원칙과 완전 일치 — [kinu.care](https://kinu.care/blog/uphabit-alternatives); [Intriq](https://www.intriq.app/personal-crm/)
13. **관계 건강 점수 · 식어 감 표시** — Cloze · Rings AI · Introhive · Nat · Mesh(?). 반응: Cloze 가 부정적 이름을 바꿈. 적합도: **불가(원칙 위배)**. 허용되는 변형: "마지막 기록 후 경과"를 사람 화면 안에서만, 순위 없이 — [crm.org](https://crm.org/news/cloze-smart-contact-sorting-for-personal-and-pro-use)
14. **오늘 연락할 사람 목록(agenda)** — Cloze AI agenda · Dex. 적합도: **하** — 순위표처럼 읽힐 위험. 대신 "오늘의 기념일(생일 · 알게 된 날)" 같은 날짜 기반 목록은 점수 없이 가능 — [Dex: Cloze review](https://getdex.com/blog/cloze-crm-review/)
15. **일기와의 연결** — Monica(일기) · Apple Journal(기기 내 제안에 자주 연락한 사람). 적합도: **중** — 공유 기록이 이미 일기 역할. Journaling Suggestions API 연동은 별도 검토 — [Monica](https://www.monicahq.com/en/); [9to5Mac](https://9to5mac.com/2026/01/05/ipados-26-adds-new-journal-app-and-ive-been-using-it-almost-every-day/)
16. **여러 금고(vault) · 분리 공간** — Monica. 적합도: **하** — 개인용 단일 사용자 앱에선 우선순위 낮음 — [itsfoss](https://itsfoss.com/monica/)

### Inferences
- 느린 인연이 이미 가진 것 중 **시장에서 드문 것**: 구조화된 첫 인연 · 소개자, 다참여자 공유 기록, 관계도 + 군집 + 시간 막대, 점수 없는 입력 상태 안내. 이를 앱 설명의 중심에 두는 것이 차별화다(단, "없는 기능을 팔지 않는다" 규칙에 따라 실제 있는 것만).
- **들여오기 우선순위 제안**: 생일 · 알게 된 날 알림(2) → vCard 내보내기(12) → 사람이 고른 소수용 부드러운 연락 주기(1) → 인생 사건 기록 유형(3) → 군집을 그룹으로 저장(5) → 명함 연속 촬영(8).
- 자동 보강 · LinkedIn · 클라우드 AI(7 · 9 · 10 의 메일 부분)는 경쟁 앱의 핵심 장점이지만 네트워크 요청 0 원칙과 정면 충돌하므로 "하지 않는 것"으로 문서화하는 편이 낫다.

### Gaps
- 각 아이디어의 사용 빈도 · 유지율 데이터(어느 기능이 실제로 오래 쓰이는가)는 공개 자료를 찾지 못했다.
- 다참여자 기록 · 소개자 칸을 가진 소비자 앱이 정말 없는지는 공식 기능 목록을 직접 읽지 못해 확정할 수 없다.
