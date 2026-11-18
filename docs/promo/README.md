# 홍보 영상 만드는 스크립트 (유튜브 쇼츠)

- `make_short.py` — 쇼츠 1 **이 사람, 어디서 만났더라?** (2026-11-01 · `../promo-youtube.md`)
- `make_map.py` — 쇼츠 2 **내 인맥을 지도로** (2026-11-02 · `../promo-youtube-2.md`) · `make_short.py` 의 그리기 도구를 가져다 쓴다
- `make_record.py` — 쇼츠 3 **만나고 30초 기록** (2026-11-03 · `../promo-youtube-3.md`) · 화면은 1.0 을 낸 커밋 `134054a` 의 스크린샷을 git 에서 꺼내 쓴다
- `make_year.py` — 쇼츠 4 **올해, 누구와 보냈나요?** (2026-11-04 · `../promo-youtube-4.md`)
- `make_plan.py` — 쇼츠 5 **약속 그다음까지** (2026-11-05 · `../promo-youtube-5.md`) · 지금 브랜치의 스크린샷 10 · 41 · 42 와 결과 적기 알림 문구
- `make_brief.py` — 쇼츠 8 **만나기 전 30초** (2026-11-08 · `../promo-youtube-8.md`) · 스크린샷 48 과 스크린샷 49 의 줄 · 문구 그대로 그린 다음에 이야기할 것
- `make_widget.py` — 쇼츠 7 **홈 화면에서 만나는 인연** (2026-11-07 · `../promo-youtube-7.md`) · 스크린샷 48 · 50 과 위젯 코드 그대로 그린 홈 · 잠금 화면 위젯
- `make_quiet.py` — 쇼츠 10 **6개월째 연락 없는 사람, 몇 명인지 아세요?** (2026-11-12 · `../promo-youtube-10.md`) · 스크린샷 18 과 연락 주기 칸 · 알림 문구 그대로 그린 장면
- `make_cards.py` — 쇼츠 9 **명함 30장, 누가 누군지 기억나요?** (2026-11-09 · `../promo-youtube-9.md`) · 스크린샷 52 와 명함 여러 장 등록 · 첫 인연 · 검색 문구 그대로 그린 장면
- `make_story.py` — 쇼츠 11 **연락처 812명, 힘든 날 전화할 사람은 몇 명인가요?** (2026-11-15 · `../promo-youtube-11.md`) · 이야기형 — 스크린샷 03 · 47 과 `make_quiet.py` 의 연락 주기 알림
- `make_intro.py` — 쇼츠 12 **지금 가까운 그 사람, 처음엔 누구 소개였나요?** (2026-11-17 · `../promo-youtube-12.md`) · 0초부터 글이 뜬 첫 장면 · 스크린샷 30 · 16 과 소개 문구 그대로 그린 장면
- `make_firstmet.py` — 쇼츠 13 **가까운 사람 10명, 처음 만난 날 다 기억하나요?** (2026-11-18 · `../promo-youtube-13.md`) · 0초 장면에 질문 · 스크린샷 20 · 31 과 첫 인연 칸 · 시작점 · n주년 알림 문구 그대로 그린 장면
- `make_day.py` — 쇼츠 6 **그날을 잊지 않게** (2026-11-06 · `../promo-youtube-6.md`) · 스크린샷 03 과 앱 문구 그대로 그린 기념일 칸 · 설정 알림 칸 · 알림

장면마다 프레임을 PIL 로 그리고 ffmpeg 로 묶는다(1080 × 1920 · 30fps · H.264 · 무음 스테레오 AAC). 앱 화면은 저장소의
CI 스크린샷 · 스토어 녹화본이고 사람은 모두 지어낸 견본이다. 영상 파일은 저장소에 두지 않는다.

## 문안 규칙

- **설명과 고정 댓글 모두 App Store 링크를 넣는다** (2026-11-16 사용자). 쇼츠 1 ~ 9 는 링크 없이, 쇼츠 10 · 11 은 고정 댓글에만 넣었다.
  주소: `https://apps.apple.com/kr/app/%EB%8A%90%EB%A6%B0-%EC%9D%B8%EC%97%B0/id6824067748`
- 제목은 한글 · 첫 2초는 숫자 하나 + 질문(`../promo-youtube-stats.md`).
- **0초 장면에 질문 글이 이미 다 떠 있다** (2026-11-17 사용자 · 쇼츠 11 이 5시간에 조회수 1회). 쇼츠 피드는 첫 장면으로 넘길지가 갈린다 —
  쇼츠 1 ~ 11 은 첫 글이 0.05초부터 떠올라 0초 장면이 빈 어두운 바탕이었다. 첫 장면의 숫자 · 질문은 나타나는 효과 없이 처음부터 그려 둔다
  (`text(..., t0=-1)` 처럼 이미 지난 시각을 준다). 움직임은 그 뒤의 작은 것(줄 · 카드)에만.

## 조회수 자동 수집 (2026-11-16 사용자 — 화면을 찍어 보내는 일을 없앤다)

`.github/workflows/promo-stats.yml` 이 매주 월요일 08:41(한국 시간)에 돈다. **Actions → 쇼츠 조회수 · App Store 획득 경로 → Run workflow** 로 바로 돌릴 수도 있다.

| 무엇 | 어디에 남나 | 스크립트 |
|---|---|---|
| 영상별 조회수 · 좋아요 · 댓글 · 평균 시청률 · 평균 시청 시간 (세 앱 쇼츠 전부) | `docs/promo-youtube-stats.md` 새 회차 + `docs/promo-stats/날짜.json` (공개) | `Tools/promo-stats/youtube_stats.py` |
| App Store 획득 경로 — 출처 유형 · 출처 정보별 노출 · 페이지 보기 · 내려받기 | **비공개 저장소** `STATS_REPO` 의 `slow-connection/appstore/날짜.md` | `Tools/promo-stats/appstore_sources.py` |

- 노출 수 · 노출 클릭률은 API 에 없어 YouTube Studio 에서만 본다.
- 이 저장소는 공개라 **Actions 기록 · 요약 · 결과 파일도 누구나 본다.** 그래서 App Store 숫자는 기록에 찍지 않고 비공개 저장소에만 커밋한다.
- 시크릿이 없으면 그 단계만 경고를 남기고 건너뛴다.

### 준비 A — 유튜브 (한 번 · 15분쯤)

1. Google Cloud 콘솔에서 새 프로젝트를 만든다 (이름 예: `slow-stats`).
2. **API 및 서비스 → 라이브러리** 에서 `YouTube Data API v3` 와 `YouTube Analytics API` 를 **사용** 으로.
3. **OAuth 동의 화면**: 사용자 유형 **외부** → 앱 이름 · 지원 메일만 채우고 저장 → 마지막에 **앱 게시(프로덕션으로)**.
   테스트 상태로 두면 갱신 토큰이 7일 뒤 끊긴다. 검수를 받지 않은 앱이라 허락할 때 경고가 뜨는데, 내 앱이니 **고급 → 이동** 으로 넘어간다.
4. **사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID** → 유형 **웹 애플리케이션** →
   승인된 리디렉션 URI 에 `https://developers.google.com/oauthplayground` → 만들기 → 클라이언트 ID · 클라이언트 보안 비밀번호를 적어 둔다.
5. `https://developers.google.com/oauthplayground` 를 연다 → 오른쪽 위 톱니 → **Use your own OAuth credentials** 체크 → 4번의 ID · 비밀번호.
   왼쪽 아래 칸에 범위 두 개를 빈칸으로 이어 넣는다:
   `https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/yt-analytics.readonly`
   → **Authorize APIs** → 채널 주인 계정으로 로그인(채널이 브랜드 계정이면 **느린 나눔** 채널을 고른다) →
   **Exchange authorization code for tokens** → 나온 **Refresh token** 을 적어 둔다.
6. GitHub 이 저장소 → **Settings → Secrets and variables → Actions → New repository secret** 으로 셋:
   `YT_CLIENT_ID` · `YT_CLIENT_SECRET` · `YT_REFRESH_TOKEN`.

### 준비 B — App Store 획득 경로 (한 번 · 10분쯤)

1. GitHub 에 **비공개(Private)** 저장소를 새로 만든다 (이름 예: `slow-stats` · **Add a README file 체크** — 빈 저장소는 받아 오지 못한다).
2. GitHub 프로필 → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token** →
   Repository access **Only select repositories** 에 1번 저장소 하나 → Permissions 의 **Contents: Read and write** → 만료는 1년.
3. 이 저장소 → Settings → Secrets and variables → Actions:
   **Secrets** 탭에 `STATS_REPO_TOKEN`(2번 토큰), **Variables** 탭에 `STATS_REPO` = `소유자/저장소이름`(예: `helpnara/slow-stats`).
4. App Store Connect → **사용자 및 액세스 → 통합 → App Store Connect API** 에서 TestFlight 에 쓰는 키(`APP_STORE_CONNECT_KEY_ID`)의
   **액세스가 관리자** 인지 본다. 분석 보고서 요청을 처음 만들 때 관리자 권한이 있어야 한다. 아니면 관리자 키를 새로 만들어 세 시크릿을 바꾼다.
5. 첫 실행이 보고서 요청을 만든다. **보고서는 하루 이틀 뒤부터** 나오니, 숫자는 그다음 실행부터 보인다.

**준비 상태** — 준비 A(유튜브) 2026-11-18 다른 세션에서 시험 · 준비 B(App Store) 2026-11-18 완료(사용자 · 비공개 저장소 `STATS_REPO` · fine-grained 토큰 `STATS_REPO_TOKEN`). 첫 실행(run 2 · 2026-11-18 15:08)이 비공개 저장소에 `slow-connection/appstore/2026-11-18.md` 를 올렸다. 토큰이 만료되면 그 단계만 실패한다 — 새 토큰으로 같은 이름의 시크릿을 Update.

## 다시 만들 때

```
mkdir -p docs/promo/font
# Noto Sans KR (OFL — 영상에 써도 된다). Google Fonts CSS 가 주는 TTF 주소로 받는다:
curl -sS "https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@500;800" | grep -o "https://[^)]*\.ttf"
# 첫 주소 → docs/promo/font/NotoSansKR-Medium.ttf, 둘째 → docs/promo/font/NotoSansKR-ExtraBold.ttf
python3 docs/promo/make_short.py . short1.mp4
python3 docs/promo/make_map.py . short2.mp4
python3 docs/promo/make_record.py . short3.mp4
python3 docs/promo/make_year.py . short4.mp4
python3 docs/promo/make_plan.py . short5.mp4
python3 docs/promo/make_day.py . short6.mp4
python3 docs/promo/make_widget.py . short7.mp4
python3 docs/promo/make_brief.py . short8.mp4
python3 docs/promo/make_cards.py . short9.mp4
python3 docs/promo/make_quiet.py . short10.mp4
python3 docs/promo/make_story.py . short11.mp4
python3 docs/promo/make_intro.py . short12.mp4
python3 docs/promo/make_firstmet.py . short13.mp4
```

- 필요한 것: Python 3 · Pillow · ffmpeg. 글꼴 폴더 `font/` 는 커밋하지 않는다(6MB × 2).
- `make_short.py` 의 기록 · 관계도 장면은 `screenshots/store/upload/preview-iphone.mp4` 의 초(4.3 ~ 7.1 · 9.5 ~ 16.3)를 쓴다 —
  CI 가 녹화본을 다시 찍으면 장면 초가 달라질 수 있으니 먼저 프레임을 뽑아 확인한다.
- 스크린샷은 CI 가 새 판으로 다시 찍는다 — **아직 출시 전인 기능이 화면에 섞이지 않았는지** 먼저 본다(CLAUDE.md §7).
