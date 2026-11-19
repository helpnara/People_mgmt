# 느린 나눔 채널 배너 (2026-11-19)

유튜브 채널 **느린 나눔** 의 배너(문짝 사진). 세 앱(느린 부자 · 느린 인연 · 느린 여백)을 함께 소개한다 — 사용자가 11-19 에 올렸다.

| 파일 | 무엇 |
|---|---|
| `slow-nanum-banner.png` | 올린 완성본 — 2560 × 1440 |
| `banner.html` | 원본. 글 · 색 · 자리를 여기서 고친다 |
| `rich.png` · `ties.png` · `margin.png` | 세 앱 아이콘 (각 저장소 `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` 를 복사) |
| `shot.mjs` | `banner.html` 을 2560 × 1440 PNG 로 찍는다 |

**휴대폰에는 가운데 1546 × 423 만 보인다** (`banner.html` 의 `.safe`). 글과 아이콘은 그 안에 두고, 바깥(왼쪽 위 `느린 나눔` · 오른쪽 위 `iPhone · iPad` · 수평선)은 PC · TV 에서만 보인다.
문구는 세 앱 문서에서 확인한 것만 쓴다 — 무료 · 회원가입 없음 · 광고 없음. 앱을 더하면 `.apps` 에 한 칸을 더하고 폭(`.app` width · `.apps` gap)을 줄여 안전 영역 안에 맞춘다.

## 다시 만들기

글꼴은 커서 저장소에 넣지 않는다(`fonts/` 는 `.gitignore`). Google Fonts 에서 받아 `fonts/` 에 둔다:

```
cd docs/promo/banner && mkdir -p fonts
get(){ u=$(curl -sS "https://fonts.googleapis.com/css2?family=$1:wght@$2" | grep -o "https://[^)]*\.ttf" | head -1); curl -sS -o "fonts/$3" "$u"; }
get Noto+Sans+KR 500 NotoSansKR-500.ttf;  get Noto+Sans+KR 700 NotoSansKR-700.ttf
get Noto+Serif+KR 700 NotoSerifKR-700.ttf; get Noto+Serif+KR 900 NotoSerifKR-900.ttf
node shot.mjs "$(pwd)/banner.html" "$(pwd)/slow-nanum-banner.png"
```

올리는 곳: YouTube 스튜디오 → 맞춤설정 → 브랜딩 → 배너 이미지.
