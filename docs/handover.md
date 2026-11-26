# 느린 인연 이관 안내 — 다른 계정에서 이어서 관리하기

2026-11-25 작성. 이 저장소(`helpnara/People_mgmt`)의 앱 **느린 인연**을 다른 Claude 계정(또는 다른 사람)이 이어 받아 사후 관리와 기능 개선을 계속할 수 있게, 필요한 것을 한 장에 모았다.
**시크릿 값 · 개인 연락처는 적지 않았다** — 이 저장소는 공개다. 값은 지금처럼 GitHub 저장소 설정 안에만 있다.

---

## 0. 새 계정의 첫 세션에서 할 일

1. Claude Code(웹 · 앱)에서 저장소 `helpnara/People_mgmt` 를 붙이고, 브랜치 **`claude/slow-connection`** 에서 세션을 연다.
2. 첫 메시지 예시 (그대로 붙여 넣어도 된다):

   > 이 저장소의 앱 느린 인연을 이어서 관리한다. `docs/handover.md` 를 먼저 읽고, `CLAUDE.md` §0 의 순서대로 `docs/roadmap.md` · `docs/08-feedback.md` 를 읽은 뒤 지금 상태를 한 줄로 알려 줘.

3. 세션이 `CLAUDE.md` 를 자동으로 읽는다. 일하는 규칙은 전부 거기에 있다 — 이 문서는 **계정이 바뀔 때 따라오지 않는 것**과 **처음 보는 사람이 놓치기 쉬운 것**만 다룬다.
4. 아래 §3 의 준비 표를 위에서부터 확인한다.

---

## 1. 지금 상태 (2026-11-25)

| 항목 | 값 |
|---|---|
| App Store | **1.1.15 (빌드 80)** — 2026-11-23 출시 · 대한민국 · 무료 · 앱 ID `6824067748` |
| 출시한 판 | 1.0 (37) · 1.1.2 (52) · 1.1.4 (55) · 1.1.6 (58) · 1.1.7 (60) · 1.1.9 (65) · 1.1.10 (67) · 1.1.11 (72) · 1.1.12 (75) · 1.1.13 (76) · 1.1.14 (77) · 1.1.15 (80) |
| 다음 판 번호 | `project.yml` 의 `MARKETING_VERSION` 이 아직 `1.1.15` — 다음 묶음을 시작할 때 `1.1.16` 으로 올린다 |
| 다음 빌드 번호 | TestFlight 워크플로 **실행 번호**가 곧 빌드 번호 — 다음은 81 |
| 스키마 | SwiftData **13판** · CloudKit Production 배포 끝(2026-11-17) |
| 개발 도구 | Xcode 27.1 · iOS 27.1 SDK · Swift 6.4 · 최소 iOS 17 · GitHub 러너 `xcode-27` |
| `main` | 1.1.15 제출 때 병합 `57e7f83` (App Store 판과 같은 코드) |
| 열린 이슈 | **125** 🔵 — CI 스크린샷 `46-choices` 가 선택지 화면이 아니라 홈으로 찍힌다(앱 기능은 정상 · 실기기 확인함). 자세한 것은 `docs/08-feedback.md` 맨 위 표 |
| 남은 정리 | GitHub 에 임시 브랜치 `pending/choice-keep-reason` 이 남아 있다(빌드 80 을 올린 브랜치 · 내용은 작업 브랜치에 이미 들어감). 원격 세션 권한으로 못 지웠다 — 저장소 Branches 화면에서 지우면 된다 |

---

## 2. 저장소 · 브랜치 한눈에

| 무엇 | 어디 |
|---|---|
| 작업 브랜치 | **`claude/slow-connection`** — 개발 · CI · TestFlight · 처리방침 게시가 모두 여기서 돈다 |
| App Store 판 | **`main`** — 심사에 낼 때 작업 브랜치를 **병합**(강제 푸시 · 되감기 없이, 스크린샷 충돌은 `-X theirs`) |
| 일하는 규칙 | `CLAUDE.md` (한글로 답 · 결정은 선택지로 · 시각은 한국 시간 · 체크리스트 형식 · 디자인 원칙 · 개인정보) |
| 지금 어디까지 | `docs/roadmap.md` 맨 위 한 줄 |
| 이슈 · 빌드 기록 | `docs/08-feedback.md` (맨 위 `지금 열린 것` 표 · 아래 `기록` 에 빌드마다 체크리스트와 사용자 답) |
| 요구사항 · 결정 | `docs/requirements-v0.5.md` (FR · D-번호 결정 표) · `docs/adr/` |
| CI · TestFlight · CloudKit 절차 | `docs/06-ci.md` (§4 자주 나는 오류 표를 꼭 본다) |
| 스토어 문안 · 제출 시트 | `docs/store-listing.md` (맨 위가 최신 판) |
| 처리방침 · 도움말 | `docs/privacy.md` · `docs/support.md` → GitHub Pages |
| 홍보(쇼츠) | `docs/promo/README.md` · `docs/promo-youtube-N.md` · `docs/promo/calendar/` · `docs/promo-youtube-stats.md` |
| 참고 앱 | 느린 부자 `helpnara/Asset-management` · 느린 여백 `helpnara/MD_Management` — 같은 팀 · 같은 규칙. 체크리스트 형식은 느린 부자를 따랐다 |

---

## 3. 계정이 바뀌면 확인할 것

### 3.1 그대로 따라오는 것 (할 일 없음)

- **GitHub Actions 시크릿 · 변수** — 저장소에 붙어 있어 Claude 계정과 상관없다. 저장소를 옮기지(소유자 변경 · 포크) 않는 한 그대로 돈다.
- **Apple 개발자 팀 · App Store Connect · CloudKit 컨테이너** — 시크릿의 API 키로 돈다. Claude 계정과 상관없다.
- **문서 · 이슈 기록 · 정답표** — 전부 저장소 안에 있다. 세션은 기억하지 못하고 문서가 기억한다.

### 3.2 새 계정에서 다시 해야 하는 것

| # | 할 일 | 어디서 | 왜 |
|---|---|---|---|
| 1 | 새 Claude 계정에 GitHub 연결 · **Claude GitHub App** 이 `helpnara/People_mgmt` 에 쓰기 권한으로 설치되어 있는지 확인 | claude.ai → 설정 → 커넥터(GitHub) | 푸시 · Actions 실행 · 로그 읽기(`actions_list` · `get_job_logs` · `actions_run_trigger`)가 모두 이 권한으로 된다 |
| 2 | 비공개 저장소 `helpnara/slow-stats` 읽기 권한 | 같은 곳 | App Store 획득 경로 숫자가 여기에만 있다(공개 저장소에는 숫자를 남기지 않는다) |
| 3 | **예약 작업 다시 만들기** — 아래 §3.3 | claude.ai 의 예약 작업 · 세션에서 `create_trigger` | 예약 작업은 계정에 붙어 있어 옮겨지지 않는다 |
| 4 | 이전 계정의 예약 작업 끄기 | 이전 계정 | 두 계정이 같은 보고를 두 번 하지 않게 |
| 5 | 클라우드 환경 | Claude Code 환경 설정 | 특별한 설정이 필요 없다. 리눅스 컨테이너라 **Swift · Xcode 를 설치하지 않는다**(`download.swift.org` 는 막혀 있고, 막혀 있어도 된다 — 컴파일은 CI 가 한다 · `CLAUDE.md` §3) |

저장소 소유자를 바꾸거나 새 저장소로 옮기는 경우에만 §3.4 를 한다.

### 3.3 예약 작업 — 새 계정에서 다시 만들 것

**쇼츠 주간 분석 보고 (이 저장소 일)** — **2026-11-28 (토) 부터 매주 토요일 · 코워크 예약 작업**(2026-11-25 사용자). 그 전에는 claude.ai 예약 작업(금 05:31 · Sonnet)이 했다 — 둘이 함께 돌면 분석이 두 번 되므로 **옛 것은 끈다**.
`promo-stats.yml` 이 금 03:13 · 04:41 에 숫자를 모은 뒤(GitHub 예약 실행은 몇 시간 늦을 수 있다 — 11-20 은 10:25), 코워크가 토요일에 그 회차를 분석해 `docs/promo-stats/report-날짜.md` **한 파일만** 올리고 보고한다. `promo-youtube-stats.md` 는 수집 워크플로만 쓴다.
코워크 지시문(2026-11-25 사용자가 넣은 것에서 **2번을 토요일용으로** 고친 판 — 오늘 이름의 JSON 을 찾으면 토요일에는 없어서 수집을 한 번 더 돌리게 된다):

```
느린 시리즈 유튜브 쇼츠(채널 '느린 나눔')의 이번 주 자동 수집 결과를 분석해 사용자에게 보고하는 일이다(사용자 2026-11-25 요청 — 매주 토요일에 보고). 사용자에게 보이는 글은 전부 한글로 쓰고, 시각은 한국 시간(KST)으로 말한다. 결정이 필요한 것은 선택지로 묻는다.

1. 공개 저장소 https://github.com/helpnara/People_mgmt 의 브랜치 claude/slow-connection 을 clone 한다. CLAUDE.md 와 docs/promo-youtube-stats.md 를 읽는다.
2. 이번 주 수집 확인: 수집 워크플로 promo-stats.yml 은 매주 금요일 03:13 · 04:41(KST) 두 번 돈다(GitHub 예약 실행은 몇 시간 늦을 수 있다). 이번 주 금요일(KST · 토요일에 돌면 어제) 이름의 docs/promo-stats/YYYY-MM-DD.json 이 있는지 본다. 있으면 그것이 이번 회차다 — 오늘 날짜 파일이 없다고 수집을 다시 돌리지 않는다. 금요일 파일이 없으면 GitHub 커넥터(actions_list)로 promo-stats.yml 의 최근 실행을 본다. 도는 중이면 몇 분 기다려 다시 받는다. 금요일 이후 실행이 없거나 실패했으면 GitHub 커넥터(actions_run_trigger)로 promo-stats.yml 을 main 에서 workflow_dispatch 로 한 번만 돌리고, 5~10분 기다려 끝나면 다시 받는다(이 수동 실행은 사용자가 허락했다) — 이때는 오늘 날짜 파일이 이번 회차다. 그래도 실패면 사유(get_job_logs)를 보고하고 끝낸다. 시크릿 · 개인정보 값은 보고에 적지 않는다.
3. 분석: 이번 회차 JSON 과 바로 앞 회차 JSON 을 파이썬으로 견준다(수동 실행으로 생긴 중간 회차가 있으면 지난주 분석 파일 docs/promo-stats/report-*.md 의 회차와도 견준다). 세는 기준은 수집 문서와 같게 한다 — 공개(privacy public)이고 3분(180초) 이하인 영상만 쇼츠로 세고(5분 사용법 같은 긴 영상은 뺀다), 앱 나누기는 Tools/promo-stats/youtube_stats.py 의 app_of 를 import 해서 그대로 쓴다. 숫자 요약이 promo-youtube-stats.md 의 그 회차 자동 표와 같은지 맞춰 보고, 다르면 까닭을 적는다. 볼 것 — 앱별(인연 · 부자 · 여백) 편 수 · 조회수 합 · 가운데값 · 앞 회차보다 늘어난 조회수, 새로 공개된 영상의 성적(publishedAt 을 KST 로 · 공개 24시간 조회수를 기준으로 견준다 — 3회차 분석: 쇼츠는 첫날이 곧 결과), 문서의 `다음 1주 게시 일정` · `다음에 볼 것` · `다음에 쓸 것` 에 적힌 시험(06:30 · 12:00 · 18~19시 공개 시각, 주제를 바꾼 편, 여백 · 인연의 돈 · 시간 다리)의 결과, 공개 시기별 앱 가운데값(채널의 결이 부자 쪽으로 기우는지), 평균 시청률. 숫자는 반드시 원자료에서 계산하고 지어내지 않는다. 편 수가 적으면 가설이라고 적는다.
4. 기록: 분석을 새 파일 docs/promo-stats/report-YYYY-MM-DD.md(오늘 KST 날짜)로 만들어 GitHub 커넥터(create_or_update_file)로 helpnara/People_mgmt 의 claude/slow-connection 에 올린다. 커밋 메시지 끝에 [skip ci]. 이 파일 하나만 새로 만들고, promo-youtube-stats.md 를 포함한 다른 파일 · 다른 브랜치 · 다른 저장소는 건드리지 않는다(이 브랜치로 올리는 것은 사용자가 허락했다). 올리기가 안 되면 기록은 건너뛰고 보고에 그 사실을 적는다.
5. 보고: 마지막 답에 한글로 짧게 — ① 이번 주 숫자 요약 표(앱별) ② 잘된 편 · 안된 편 각 1~3개와 까닭 ③ 시각 실험 결과 ④ 다음 주 쇼츠에 쓸 것 3가지 ⑤ 사용자가 할 일(있으면). 영상 제작이나 게시 일정 변경은 하지 말고 제안만 한다.
```

코워크에 필요한 것: **GitHub 커넥터**(`actions_list` · `actions_run_trigger` · `get_job_logs` · `create_or_update_file` — 없으면 4번 기록이 건너뛰어진다) · 예약 시각에 **컴퓨터와 Claude 앱이 켜져 있을 것**(코워크 예약 작업은 그 컴퓨터에서 돈다).

**이전 계정에 걸려 있는 다른 알림 (다른 앱 일 · 이 저장소와 상관없음)** — 필요하면 그 앱을 맡는 계정에서 다시 건다:
`12-01 프로모션 텍스트 되돌리기`(느린 여백) · `다음 버전 · TestFlight 새 빌드 착수 여쭙기`(12-01 · 느린 부자) · `에디터 추천 신청 알림`(12-21 · 느린 부자) · `2.0 기능 고르기 알림`(2027-01-11 · 느린 부자).

### 3.4 저장소를 옮길 때만 — 다시 넣을 시크릿 · 변수

시크릿은 쓰기 전용이라 다른 저장소에서 꺼내 올 수 없다. **원본(`.p8` 파일 등)을 가진 사람이 다시 넣어야 한다.**

| 이름 | 종류 | 쓰는 곳 | 메모 |
|---|---|---|---|
| `APPLE_TEAM_ID` | 시크릿 | `testflight.yml` · `cloudkit-schema.yml` | 느린 부자 · 느린 여백과 같은 값 |
| `APP_STORE_CONNECT_KEY_ID` | 시크릿 | TestFlight · App Store 획득 경로 | 팀 단위 API 키 — 액세스는 **Admin** 이어야 서명 자산을 만든다 |
| `APP_STORE_CONNECT_ISSUER_ID` | 시크릿 | 같은 곳 | |
| `APP_STORE_CONNECT_KEY_P8` | 시크릿 | 같은 곳 | `.p8` 원문을 줄바꿈까지 그대로 |
| `CKTOOL_MGMT_TOKEN` | 시크릿 | `cloudkit-schema.yml` | **2026-10-19 발급 · 2027-10-19 만료** — 만료돼도 앱 · 동기화 · TestFlight 는 멀쩡하고 스키마를 올릴 때만 막힌다 (`docs/06-ci.md` §7) |
| `YT_CLIENT_ID` · `YT_CLIENT_SECRET` · `YT_REFRESH_TOKEN` | 시크릿 | `promo-stats.yml` (쇼츠 조회수) | `docs/promo/README.md` 준비 A |
| `STATS_REPO_TOKEN` | 시크릿 | `promo-stats.yml` (비공개 저장소에 쓰기) | fine-grained 토큰 · 만료되면 그 단계만 실패 — `docs/promo/README.md` 준비 B |
| `STATS_REPO` | 변수 | 같은 곳 | `helpnara/slow-stats` |
| `SUPPORT_EMAIL` | 변수 | `site.yml` (처리방침 · 도움말) | 비어 있으면 처리방침을 게시하지 않는다 |

함께 할 것: 기본 브랜치를 `main` 으로 · Pages Source 를 **GitHub Actions** 로 · 수동 실행 워크플로(`testflight.yml` · `probe.yml` · `cloudkit-schema.yml` · `promo-stats.yml`)는 기본 브랜치에도 파일이 있어야 Actions 목록에 뜬다(`docs/06-ci.md` §2.1). App Store 의 **지원 URL · 처리방침 URL** 이 Pages 주소를 가리키므로 주소가 바뀌면 콘솔에서도 고친다.

---

## 4. 식별자 (바꾸지 않는다)

| 무엇 | 값 |
|---|---|
| 앱 이름 | 느린 인연 (영문 Slow Ties) |
| 번들 ID | `com.helpnara.slow.connection` · 위젯 `.widget` · 공유 시트 `.share` · 시험 `.tests` · `.uitests` |
| iCloud 컨테이너 | `iCloud.com.helpnara.slow.connection` |
| App Group | `group.com.helpnara.slow.connection` |
| App Store 앱 ID · SKU | `6824067748` · `slowconnection` |
| App Store 주소 | `docs/store-listing.md` 맨 위 |
| 처리방침 | `https://helpnara.github.io/People_mgmt/privacy/` |

번들 ID 나 컨테이너를 바꾸면 사용자의 iCloud 자료 · TestFlight 설치본과 남남이 된다.

---

## 5. 한 판이 나가는 흐름

1. **이슈 쌓기** — 사용자가 쓰다 가져온 것을 `docs/08-feedback.md` 표에 번호 · 상태(🔴🟡🔵🟢) · 사용자 말 그대로 적는다. 5개 안팎이 모이면 "착수할까요?" 를 선택지로 묻는다. 자료 유실 · 저장 실패만 바로 고친다.
2. **고치기** — 같은 역할이 이미 있는지 `grep` 부터. 순수 로직은 `Packages/Core`(Foundation 만), 기댓값은 `Tools/golden/` 파이썬이 계산한 JSON 만 쓴다(지어내지 않는다).
3. **푸시 전 여기서 돌릴 것** — `python3 Tools/golden/generate.py --check` · `python3 Tools/cloudkit/generate-ckdb.py --check` · `python3 Tools/privacy/check-privacy-manifest.py` (색을 바꿨으면 `Tools/contrast.py`).
4. **CI** — 코드 푸시마다 `core-test.yml`(2~4분) · `ios.yml`(빌드 → 앱 시험 → 스크린샷 → 화면 이동 시험 · 전체 2시간 안팎)이 돈다. 스크린샷은 `screenshots/` 로 되돌려 커밋된다 — `git pull` 뒤 Read 해서 본다.
5. **TestFlight** — 사용자가 "착수하자" 라고 할 때만 `testflight.yml` 을 수동 실행. 빌드와 앱 시험이 초록이면 업로드는 스크린샷을 기다리지 않아도 된다. 체크리스트는 스크린샷을 본 뒤에 준다 — 사용자가 먼저 받기를 고르면 코드로 확인한 표를 주고, 스크린샷이 오면 다시 본다.
6. **체크리스트** — 느린 부자 방식 표(`CLAUDE.md` §4-2). 항목마다 화면 · 단추 · 문구 · 전체 경로 · 조건을 **코드에서 확인**하고, 같은 표를 `docs/08-feedback.md` 에 남긴다. 사용자는 "0~n 확인 완료" 로 답한다.
7. **제출 준비** — `docs/store-listing.md` 맨 위에 새 판 제출 시트(새로운 기능 · 설명 · 영문 심사 메모, 글자 수를 세어 적는다) → 작업 브랜치를 `main` 에 병합 → "제출 준비 끝" 을 알린다.
8. **출시 기록** — 사용자가 승인 · 배포를 알리면 `README.md` · `docs/roadmap.md` · `docs/08-feedback.md` · `docs/store-listing.md` · `docs/slow-series-slow-connection.md` 의 지금 판을 올린다.
9. **스키마를 바꾸는 판**이면 추가로 — `generate-ckdb.py` 로 파일을 다시 만들고 → Actions → CloudKit 스키마(`apply`) → **사용자가 CloudKit 콘솔에서 Production 으로 Deploy** — 배포 전 빌드를 내면 그 기기의 iCloud 올리기가 거부된다(`docs/06-ci.md` §7).

---

## 6. 알아 둘 함정 (최근에 겪은 것)

| 증상 | 할 일 |
|---|---|
| TestFlight 아카이브가 `... .share" doesn't include signing certificate "Apple Development: Created via API"` 로 실패 | 애플 쪽 시차 — 같은 실행을 **한 번** 다시 돌린다(빌드 78 이 두 번째에 통과) |
| TestFlight 아카이브가 `The Internet connection appears to be offline` → `No profiles for ...` 로 실패 | 러너 연결 끊김 — 한 번 다시 돌린다(빌드 79) |
| 실패 로그 맨 아래 안내 세 줄(인증서 꽉 참 · 기기 없음 · App ID 없음) | 실패하면 **늘** 찍히는 일반 안내다. 위쪽의 실제 `error:` 줄을 찾는다 |
| 스크린샷을 찍는 CI 가 도는 중에 코드를 푸시하면 그 실행이 취소된다(`cancel-in-progress`) | 푸시를 모은다. 급하면 수정 커밋을 CI 가 돌지 않는 임시 브랜치(예: `pending/…`)에 올리고 그 브랜치에서 `testflight.yml` 을 돌린 뒤, 나중에 작업 브랜치로 가져온다(빌드 80 이 이렇게 나갔다) |
| `ios.yml` 실행이 일 없이 바로 실패하고 이름이 파일 경로(`.github/workflows/ios.yml`)로 뜬다 | 워크플로 파일을 GitHub 가 못 읽은 것. 스크린샷 단계처럼 긴 `run:` 안에 `${{ }}` 가 있으면 글 전체가 식이 되어 21,000자 한도에 걸린다 — 값은 `env:` 로 넘긴다(CI 187 · 2026-11-25) |
| 문서만 고친 푸시 | `ios.yml` 이 건너뛴다(`paths-ignore`) — 마음 놓고 올려도 된다 |
| 화면 이동 시험이 가끔 `Timed out while evaluating UI query` | 러너의 화면 구조 읽기가 들쭉날쭉한 것으로 결론(이슈 120 닫음). 단계별 시간 로그(`단계 -[…`)가 남으니 다시 나면 그 줄부터 본다 |
| 사용자가 보낸 실기기 화면 사진 | **실제 사람 이름이 있다.** 문서 · 커밋에는 옮기지 않거나 지어낸 예시로 바꾼다 |
| 내년(Xcode 28) | 시험 브랜치에서 러너 이름만 바꿔 한 번 돌려 본 뒤 합친다(1.1.14 에서 Xcode 27 로 옮긴 방법 · `docs/06-ci.md` §1) |

---

## 7. 다가오는 날짜

| 날짜 | 무엇 |
|---|---|
| 매주 금 03:13 · 04:41 · 토 | 쇼츠 조회수 · App Store 획득 경로 수집(금) → 코워크 분석 보고(토 · 11-28 부터 · §3.3) |
| 2027-02-20 무렵 | TestFlight 빌드 80 만료(업로드 2026-11-22 + 90일). 그 전에 새 판을 내지 않으면 테스트 설치본이 사라진다 — App Store 판은 상관없다 |
| 2027-04 | Apple 이 iOS 27 SDK 빌드만 받기 시작 — 이미 Xcode 27 로 옮겨 두었다 |
| 2027-10-19 | `CKTOOL_MGMT_TOKEN` 만료 — 스키마를 바꿀 일이 있으면 그 전에 새로 만든다 |

---

## 8. 사용자와 일하는 방식 (요약 — 원문은 `CLAUDE.md`)

- 사용자에게 보이는 글은 **전부 한글**. 코드 이름 · 경로 · 명령만 `코드 글씨`.
- 결정은 **선택지로 묻고** 사용자가 고른다. 추천이 있으면 첫 번째에 `(추천)`.
- 시각은 **한국 시간**(UTC+9).
- 빌드는 사용자가 "착수하자" 할 때만. 확인은 체크리스트 표로, 사용자는 "0~n 확인 완료".
- 디자인은 늘 고급스럽게(`CLAUDE.md` §1 의 원칙).
- 쇼츠: **업로드 완료 · 고정 댓글 완료** 두 신호를 받으면 일정표 · 달력을 고치고, 답할 때마다 끝에 `python3 docs/promo/calendar/make_calendar.py` 가 찍는 고정 댓글 남은 것과 오늘 · 내일 예약을 한 줄로(`CLAUDE.md` §7).

---

## 9. 이관 확인 기록

**2026-11-25 새 세션에서 확인:**
- 작업 브랜치 `claude/slow-connection` 받음(맨 위 `201510b`) · 사용자가 이 브랜치로 푸시하도록 허락함.
- 여기서 돌리는 검사 셋 모두 통과 — 정답표 · CloudKit 스키마 파일 · 개인정보 명세.
- GitHub: `helpnara/People_mgmt` 푸시 권한 확인 · Actions 실행 기록 읽기 됨. `helpnara/slow-stats` 는 필요할 때 붙일 수 있음.
- 예약 작업 `쇼츠 주간 분석 보고 (금요일 06시 전)` 이 이 계정에 이미 켜져 있음(금 05:31 KST · Sonnet · 휴대폰 알림) — 다시 만들지 않음. 그 프롬프트는 분석을 `docs/promo-youtube-stats.md` 회차 아래에 적는다(§3.3 의 `report-날짜.md` 와 다름).
- 아직 남은 것: 이슈 125(🔵) · 임시 브랜치 `pending/choice-keep-reason` 지우기(저장소 Branches 화면).

**2026-11-25 코워크 넘김 점검** (사용자 — 11-28 토부터 쇼츠 분석을 코워크가 맡는다):
- 수집 `promo-stats.yml` 6번 모두 성공(마지막 11-24 22:45). 기본 브랜치 `main` 의 파일로 예약이 돌고, 작업 브랜치의 스크립트로 모은다. 두 번 예약(금 03:13 · 04:41)의 첫 실전은 **11-27**.
- GitHub 예약 실행은 늦는다 — 11-20 예약(04:41)이 10:25 에 시작됐다. 그래서 분석을 토요일로 옮기는 것이 오히려 안전하다.
- `Tools/promo-stats/appstore_sources.py` 는 11-25 에 고친 뒤 아직 한 번도 안 돌았다(여기서 문법 검사만 통과). 11-27 실행이 첫 시험 — 실패해도 유튜브 수집과는 따로 돈다.
- 사용자가 준 코워크 지시문의 2번(오늘 이름의 JSON)을 토요일용으로 고친 판을 §3.3 에 적었다 — **코워크 예약 작업에 고친 판을 넣어야 한다.**
- **11-25 코워크 시험 실행** (새 계정 · 쓰기 없음): clone · JSON 비교 · Actions 실행 기록 읽기 · GitHub 커넥터의 파일 쓰기 · 워크플로 실행 도구 확인 — 모두 됨. 어긋난 것 하나: 코워크가 11-15 *5분 사용법*(285초)을 부자 쇼츠에 넣고 앱을 앱 ID 로만 나눠 *미분류* 2편이 생겼다 → 지시문 3번에 *3분 이하 · `app_of` 그대로* 를 넣었다. 그 전에 올라온 `report-2026-11-25.md` 는 그 기준이라 부자가 24편 · 9,943회(수집 문서는 23편 · 9,938회)이고, 11-22 · 11-24 수동 실행을 *예약 수집이 이틀 간격으로 돈다* 로 읽었다 — 고치지 않고 둔다.
- 옛 claude.ai 예약 작업 `쇼츠 주간 분석 보고 (금요일 06시 전)` 은 11-25 사용자가 지웠다(조회되지 않음).
- 코워크 예약 작업에 §3.3 지시문(2번 토요일용 · 3번 세는 기준)을 넣음 — 11-25 사용자. 남은 확인: 11-27(금) 수집 초록 · 11-28(토) `report-2026-11-28.md` 숫자가 수집 문서의 11-27 회차 표와 같은가(사용자가 알려 주기로).
- 부자 · 여백 작업 브랜치에 빠져 있던 쇼츠 기록을 합쳤다 — 부자 25편 제작 · 업로드와 22 · 23편 고정 댓글(`claude/iphone-asset-management-design-7aafjc`), 여백 새 폰 편 고정 댓글(`claude/dreamy-pasteur-etli29`). 둘 다 다른 세션 브랜치 `claude/sleepy-newton-kg3jza` 에만 있었다.
