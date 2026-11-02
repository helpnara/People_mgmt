# 홍보 영상 만드는 스크립트 (유튜브 쇼츠)

- `make_short.py` — 쇼츠 1 **이 사람, 어디서 만났더라?** (2026-11-01 · `../promo-youtube.md`)
- `make_map.py` — 쇼츠 2 **내 인맥을 지도로** (2026-11-02 · `../promo-youtube-2.md`) · `make_short.py` 의 그리기 도구를 가져다 쓴다

장면마다 프레임을 PIL 로 그리고 ffmpeg 로 묶는다(1080 × 1920 · 30fps · H.264 · 무음 스테레오 AAC). 앱 화면은 저장소의
CI 스크린샷 · 스토어 녹화본이고 사람은 모두 지어낸 견본이다. 영상 파일은 저장소에 두지 않는다.

## 다시 만들 때

```
mkdir -p docs/promo/font
# Noto Sans KR (OFL — 영상에 써도 된다). Google Fonts CSS 가 주는 TTF 주소로 받는다:
curl -sS "https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@500;800" | grep -o "https://[^)]*\.ttf"
# 첫 주소 → docs/promo/font/NotoSansKR-Medium.ttf, 둘째 → docs/promo/font/NotoSansKR-ExtraBold.ttf
python3 docs/promo/make_short.py . short1.mp4
python3 docs/promo/make_map.py . short2.mp4
```

- 필요한 것: Python 3 · Pillow · ffmpeg. 글꼴 폴더 `font/` 는 커밋하지 않는다(6MB × 2).
- `make_short.py` 의 기록 · 관계도 장면은 `screenshots/store/upload/preview-iphone.mp4` 의 초(4.3 ~ 7.1 · 9.5 ~ 16.3)를 쓴다 —
  CI 가 녹화본을 다시 찍으면 장면 초가 달라질 수 있으니 먼저 프레임을 뽑아 확인한다.
- 스크린샷은 CI 가 새 판으로 다시 찍는다 — **아직 출시 전인 기능이 화면에 섞이지 않았는지** 먼저 본다(CLAUDE.md §7).
