# 홍보 영상 만드는 스크립트 (유튜브 쇼츠)

- `make_short.py` — 쇼츠 1 **이 사람, 어디서 만났더라?** (2026-11-01 · `../promo-youtube.md`)
- `make_map.py` — 쇼츠 2 **내 인맥을 지도로** (2026-11-02 · `../promo-youtube-2.md`) · `make_short.py` 의 그리기 도구를 가져다 쓴다
- `make_record.py` — 쇼츠 3 **만나고 30초 기록** (2026-11-03 · `../promo-youtube-3.md`) · 화면은 1.0 을 낸 커밋 `134054a` 의 스크린샷을 git 에서 꺼내 쓴다
- `make_year.py` — 쇼츠 4 **올해, 누구와 보냈나요?** (2026-11-04 · `../promo-youtube-4.md`)
- `make_plan.py` — 쇼츠 5 **약속 그다음까지** (2026-11-05 · `../promo-youtube-5.md`) · 지금 브랜치의 스크린샷 10 · 41 · 42 와 결과 적기 알림 문구
- `make_brief.py` — 쇼츠 8 **만나기 전 30초** (2026-11-08 · `../promo-youtube-8.md`) · 스크린샷 48 과 스크린샷 49 의 줄 · 문구 그대로 그린 다음에 이야기할 것
- `make_widget.py` — 쇼츠 7 **홈 화면에서 만나는 인연** (2026-11-07 · `../promo-youtube-7.md`) · 스크린샷 48 · 50 과 위젯 코드 그대로 그린 홈 · 잠금 화면 위젯
- `make_cards.py` — 쇼츠 9 **명함 30장, 누가 누군지 기억나요?** (2026-11-09 · `../promo-youtube-9.md`) · 스크린샷 52 와 명함 여러 장 등록 · 첫 인연 · 검색 문구 그대로 그린 장면
- `make_day.py` — 쇼츠 6 **그날을 잊지 않게** (2026-11-06 · `../promo-youtube-6.md`) · 스크린샷 03 과 앱 문구 그대로 그린 기념일 칸 · 설정 알림 칸 · 알림

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
python3 docs/promo/make_record.py . short3.mp4
python3 docs/promo/make_year.py . short4.mp4
python3 docs/promo/make_plan.py . short5.mp4
python3 docs/promo/make_day.py . short6.mp4
python3 docs/promo/make_widget.py . short7.mp4
python3 docs/promo/make_brief.py . short8.mp4
python3 docs/promo/make_cards.py . short9.mp4
```

- 필요한 것: Python 3 · Pillow · ffmpeg. 글꼴 폴더 `font/` 는 커밋하지 않는다(6MB × 2).
- `make_short.py` 의 기록 · 관계도 장면은 `screenshots/store/upload/preview-iphone.mp4` 의 초(4.3 ~ 7.1 · 9.5 ~ 16.3)를 쓴다 —
  CI 가 녹화본을 다시 찍으면 장면 초가 달라질 수 있으니 먼저 프레임을 뽑아 확인한다.
- 스크린샷은 CI 가 새 판으로 다시 찍는다 — **아직 출시 전인 기능이 화면에 섞이지 않았는지** 먼저 본다(CLAUDE.md §7).
