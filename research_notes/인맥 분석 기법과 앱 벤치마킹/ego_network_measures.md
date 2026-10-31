# 자아 중심(ego) 네트워크 분석 기법과 느린 인연 적용성

> 조사 범위: 한 사람(ego · 나)과 내가 기록한 사람들(alters), 그리고 그들 사이의 "아는 사이" 연결만으로 계산하는 분석 기법.
> 앱 전제: (a) 기기 내 저장만 (b) 그래프가 작다 — 수십~수천 명, 공동 참여 기록은 성기다 (c) **사람을 점수화 · 순위화하지 않는다** (ADR-0004) (d) Swift · 결정적 · 시험 가능한 계산.
> 표기: **[고전]** = 2018년 이전 기초 문헌, **[최근]** = 2018~2026. 이 세션에서는 networkx.org · arxiv.org · 일부 대학 PDF 서버가 DNS 로 막혀 원문을 직접 열지 못한 것이 있다 — 그런 항목은 검색 결과의 요약 · 서지 정보에 기댔고 본문에 표시했다.
> 저장소 맥락: `docs/adr/0004-metrics-do-not-score-people.md` 는 이미 근접 중심성 · 고유벡터 · PageRank · 중개 역할 유형 분류를 **제외**, 커뮤니티 · 매개 · 연결 수를 P2 로 두었다. 모임 찾기는 Louvain + 고정 차례(D-30)로 구현됨. 아래 판정은 이 결정과 대조해 읽는다.

---

## 1. 자아 네트워크 지표 — 어떤 것이 "나의 돌봄" 을 말하고 어떤 것이 사실상 사람 순위가 되는가

### Takeaway
자아 네트워크 지표는 **ego 단위 요약값**(크기 · 밀도 · 유효 크기 · 제약 · 다양성 · 덩어리 수)과 **alter 단위 값**(매개 · 고유벡터 · PageRank · 연결 수 · 코어 번호)으로 나뉜다. 앞의 것은 "내 인연 전체의 모양" 이라 원칙과 양립하고, 뒤의 것은 사람마다 숫자가 하나씩 붙는 순간 정렬 가능한 순위가 된다 — 뒤의 것은 숫자 대신 **범주(이 사람은 두 모임 모두에 있다)** 로만 내보내야 한다.

### Cited Findings
- **[최근] 교과서 기준점:** Perry · Pescosolido · Borgatti, *Egocentric Network Analysis: Foundations, Methods, and Models* (Cambridge UP, 2018) 는 ego 네트워크 자료의 개념화 · 수집 · 분석 · 해석 전 과정을 다루는 단일 안내서로 소개된다. 11장이 "network science 속의 ego 네트워크" (pp. 297–309) — [Indiana Univ. 소개](https://sociology.indiana.edu/research/books/2018-egocentric-network-analysis.html), [Cambridge 참고문헌 목록](https://www.cambridge.org/core/books/egocentric-network-analysis/references/0081098512AB24425BFE7FC1827EDFB5). 참고문헌에 Agresti & Agresti (1978) "Statistical analysis of qualitative variation" (IQV 계열 다양성 지수의 고전 출처)이 들어 있다 — 같은 출처. (장별 내용은 이 세션에서 확인 못 함.)
- **[고전] 유효 크기(effective size) — Burt 1992, Borgatti 1997 단순화:** 이진 · 무방향 네트워크에서 Burt 의 유효 크기는 "ego 의 차수 − ego 네트워크 안에서 alter 들의 평균 차수" 로 줄어든다. NetworkX 문서 표기는 **e(u) = n − 2t/n** (n = alter 수, t = alter 사이 연결 수, ego 와의 연결 제외). 출처는 Borgatti, "Structural Holes: Unpacking Burt's Redundancy Measures," *CONNECTIONS* 20(1):35–38 — [NetworkX effective_size 문서](https://networkx.org/documentation/stable/reference/algorithms/generated/networkx.algorithms.structuralholes.effective_size.html), [NetworkX 2.2 소스](https://networkx.org/documentation/networkx-2.2/_modules/networkx/algorithms/structuralholes.html). (DNS 문제로 원문 페이지는 직접 열지 못했고 검색 요약으로 확인.)
- **[고전] Burt 의 제약(constraint):** alter j 가 ego i 에게 주는 제약은 직접 비중 p_ij 와 다른 접촉 q 를 거친 간접 경로의 합을 **제곱**한 값이고, 총 제약은 alter 전체의 합: **c_i = Σ_j ( p_ij + Σ_{q≠i,j} p_iq · p_qj )²**. p_ij 는 i 의 연결 중 j 에 쓴 비중(정규화 상호 가중치) — [Metricgate: Burt's Structural Constraint](https://metricgate.com/calculator/burt-structural-constraint). 작은 ego 네트워크에서는 제약이 1 을 넘을 수 있고 큰 네트워크에서는 1 에 이르지 못한다는 분석이 있다 — [Univ. of Kentucky 논문 기록](https://uknowledge.uky.edu/management_facpub/4). Burt 원저의 연도 표기가 출처마다 1992 / 1995 로 다르다 — 같은 검색 결과에서 확인.
- **[고전] Gould–Fernandez (1989) 중개 역할:** 집단 구분이 주어진 상태에서 "중개자가 가운데 있는 삼자 관계" 를 집단 소속으로 분류한다. coordinator = 세 명 모두 같은 집단 / itinerant(consultant) = 다른 두 명은 같은 집단, 중개자만 다른 집단 / representative · gatekeeper = 중개자와 한 명이 같은 집단, 나머지 한 명은 다른 집단 — [Weighted and Normalized Gould-Fernandez brokerage measure (arXiv 2107.01117)](https://arxiv.org/pdf/2107.01117), [Longitudinal Analysis of a Social Network of Intellectual History (arXiv 2009.03604)](https://arxiv.org/pdf/2009.03604). 2차 출처 문구로는 representative 와 gatekeeper 가 거의 같게 서술되며, 둘의 차이는 **연결 방향**에 달려 있다 — 같은 검색 결과의 요약에서 확인(원문 미열람).
- **[최근] 중개 지표의 가중 · 정규화 판:** 2021년 arXiv 논문이 Gould–Fernandez 지표의 가중 · 정규화 판을 제안했다 — [arXiv 2107.01117](https://arxiv.org/pdf/2107.01117). 다른 응용 연구는 coordinator · gatekeeper 역할을 "그 시대 안에서 학자의 중요도" 로 해석한다 — [arXiv 2009.03604](https://arxiv.org/pdf/2009.03604). 즉 연구 현장에서도 이 역할은 **사람의 중요도**로 읽힌다.
- **[고전] k-core:** Seidman(1983)이 제안. k 보다 차수가 작은 노드를 반복해서 지워 남는 부분 그래프 — [Batagelj & Zaveršnik, An O(m) Algorithm for Cores Decomposition of Networks](https://arxiv.org/abs/cs/0310049), [NetworkX 1.9 core 문서](https://networkx.org/documentation/networkx-1.9/reference/algorithms.core.html).
- **[고전] 시간적 안정성과 구조:** Burt 의 "Decay functions" (*Social Networks* 22(1):1–28, 2000) · "Bridge decay" (*Social Networks* 24(4):333–363, 2002). 겹침이 적은 약한 연결 — 곧 **다리(bridge)** — 가 공동체 안에 묻힌 연결보다 끊기기 쉽다는 결과로 인용된다. "다리가 더 빨리 끊긴다" 는 주장은 보통 2002년 논문에 귀속된다 — [Temporal patterns behind the strength of persistent ties (arXiv 1706.06188)](https://arxiv.org/pdf/1706.06188), [Predictors of short-term decay of cell phone contacts (arXiv 1102.1753)](https://arxiv.org/pdf/1102.1753), [dblp Burt](https://dblp.dagstuhl.de/pid/79/8015.html).

### Inferences
- **ego 의 군집 계수 = alter 사이 밀도.** ego 의 국소 군집 계수는 "ego 의 이웃끼리 이어진 비율" 이고, ego 네트워크에서 ego 의 이웃은 alter 전원이므로 정의상 alter 사이 밀도 **D = 2t / (n(n−1))** 와 같다. 따로 계산 · 표시할 이유가 없다 (정의에서 직접 유도).
- **유효 크기는 크기와 밀도로 정해진다.** 2t/n = (n−1)·D 이므로 **유효 크기 = n − (n−1)·D**, 효율성 = 유효 크기 / n. 즉 이진 그래프에서는 크기 · 밀도 외의 새 정보가 없다 — 화면에는 "아는 사이로 이어진 비율" 하나로 충분하고, "유효 크기" 라는 생소한 이름을 내지 않는 편이 설명 가능성(ADR-0004 ②)에 맞다. 가중치(공동 기록 수)를 쓰면 이 동치는 깨진다.
- **느린 인연 그래프의 특성:** "아는 사이" 는 공동 참여 기록 · 소개 관계 · 사용자가 직접 이은 연결에서 나온다. 참여자 k 명인 기록 하나가 k(k−1)/2 개의 alter–alter 연결을 만든다(30명 회식 = 435개). 그래서 **밀도와 군집 계수가 큰 모임 기록 하나에 끌려간다** — 밀도를 보여 줄 때는 "큰 모임 기록에서 생긴 연결" 을 따로 셀지 정해야 한다(예: 참여자 n명 이상 기록은 약한 연결로 표시).
- **제약(constraint)은 ego 에 대해서만 의미가 있다.** ego 의 제약 = "내 인연이 한 덩어리에 몰려 있는가". alter 마다 제약을 계산하면 그 사람의 "구조적 기회" 점수가 되어 순위가 된다. 그리고 alter 의 제약은 내가 모르는 그 사람의 바깥 인연을 빼고 계산되므로 **틀린 값**이다 — 자아 중심 자료는 alter 의 전체 네트워크를 담지 않는다.
- **매개 · 고유벡터 · PageRank · 연결 수(alter 단위):** 셋 다 사람마다 실수 하나 → 정렬 가능 → 사실상 "중요한 사람 순위". 또 ego 를 그래프에 넣으면 ego 가 모두와 이어져 있어 모든 alter 사이 최단 거리가 ≤ 2 가 되고, ego 가 거의 모든 경로를 독차지한다 — alter 의 매개값은 **ego 를 뺀 alter 그래프**에서 계산해야 의미가 생긴다. 이 값도 "숫자" 로 내지 말고 **"두 모임을 잇는 사람" 이라는 범주(예/아니오)** 로만 쓰는 것이 원칙에 맞다. 고유벡터 · PageRank 는 "잘 이어진 사람과 이어진 사람" 이라 인기도 그 자체이며, ego 관점의 행동("내가 무엇을 돌볼까")으로 번역되지 않는다 — ADR-0004 의 제외 판단과 일치.
- **Gould–Fernandez 역할:** 방향 있는 연결과 집단 구분이 둘 다 필요하다. 공동 참여 그래프는 방향이 없으므로 representative/gatekeeper 를 가를 수 없다. 응용 연구에서 이 역할이 "중요도" 로 읽히는 점(위 인용)까지 보면 제외 판단(ADR-0004)이 타당하다. 단, **liaison**(세 사람이 모두 다른 집단 — 일반 교과서 정의, 이 세션에서 원문 확인 못 함)의 무방향 판 = "서로 다른 두 모임에 모두 걸친 사람" 은 Louvain 결과로 바로 셀 수 있는 범주 정보다.
- **다양성(heterogeneity):** 관계 유형 · 알게 된 경로 · 기록 유형 · 모임(커뮤니티)별 비율로 계산하는 지수는 **ego 하나에 값 하나**라 순위가 생기지 않는다. 표준 정의(이 세션에서 원문 확인 못 함 — Agresti & Agresti 1978 계열): Blau 지수 = 1 − Σ p_k², IQV = (1 − Σ p_k²) / (1 − 1/K), Shannon H = −Σ p_k ln p_k. 화면에는 숫자보다 **"범주별 사람 수 막대"** 가 낫다 — 다양성 지수 하나는 "다양할수록 좋다" 는 평가를 암시한다.
- **k-core:** alter 그래프의 가장 깊은 코어 = "서로가 서로를 아는 단단한 핵". ego 단위로 "가장 촘촘한 묶음의 크기" 정도는 중립적이지만, 사람마다 코어 번호를 붙이면 등급표가 된다.

#### 기법별 판정표 (느린 인연 기준)

| 기법 | ego 관점에서 쓸모 | 기기 내 계산 (n≤5,000 · m≤50,000) | 사람 순위로 변할 위험 | 중립적 표현 |
|---|---|---|---|---|
| ego 네트워크 크기 n | 높음 — "기록한 인연 수" | O(n), 즉시 | 없음 (ego 값) | "기록한 사람 148명" · 기간별 변화 |
| alter 사이 밀도 D (= ego 군집 계수) | 중간 — 내 인연이 서로 얽혀 있는 정도 | O(m) | 없음 | "아는 사이로 이어진 쌍의 비율" + 큰 모임 기록 영향 고지 |
| 유효 크기 · 효율성 | 낮음 — 이진에서는 n·D 로 정해짐 | O(m) | ego 만 계산하면 없음 | 따로 내지 않음 (밀도로 대체) |
| Burt 제약 (ego) | 중간 — "한 덩어리에 몰려 있나" | O(Σ deg²) 수준 | ego 만이면 없음 / alter 별이면 높음 | 숫자 대신 "인연이 n개 모임에 나뉘어 있다" 문장 |
| 덩어리(연결 요소) 수 · 모임(Louvain) 수 | 높음 — "내 인연의 지도" | O(m) / Louvain 경험적으로 거의 선형 | 낮음 (모임 크기 순 정렬만 조심) | 모임 이름 + 사람 수, 고정 차례 |
| alter 매개 중심성 (ego 제외 그래프) | 중간 — 모임 사이 다리 찾기 | Brandes O(nm) ≈ 2.5×10⁸ 단계, 백그라운드 | **높음** (실수 하나 → 정렬) | 숫자 금지. "두 모임 모두에 있는 사람" 범주로만 |
| 연결 수(degree, alter 별) | 낮음 | O(m) | **높음** ("발 넓은 사람" 순위) | 사람 상세에 "함께 아는 사람 n명" 정도까지만, 목록 정렬 기준 금지 |
| 고유벡터 · PageRank | 없음 — 인기도 | 반복법, 수렴 · 결정성 관리 필요 | **매우 높음** | 넣지 않음 (ADR-0004 제외 유지) |
| 근접 중심성 | 없음 — ego 포함 시 모두 거리 ≤2 | O(nm) | 높음 | 넣지 않음 |
| Gould–Fernandez 역할 | 낮음 — 방향 자료 없음 | O(Σ deg²) | 높음 ("중요도" 로 읽힘) | 넣지 않음. liaison 무방향 판만 범주로 |
| k-core | 중간 — "단단한 핵" | O(m) (Batagelj–Zaveršnik) | 코어 번호를 사람에 붙이면 높음 | ego 값: "서로 다 아는 핵심 묶음 n명" |
| 삼자 폐쇄 · 군집 | 중간 — 소개 제안의 근거 | 삼각형 세기 O(m·√m) 수준 | 낮음 | "A 와 B 를 둘 다 아는데 둘은 아직 이어지지 않음" (확인 요청형) |
| 다양성 (Blau · IQV · 엔트로피) | 높음 — 맥락의 폭 | O(n) | 없음 | 범주별 막대. 지수 숫자는 숨김 |
| 유대 강도 합성값 | 높음 (정렬용) | O(기록 수) | **높음** | 숫자 금지. 정렬 기준 · 구간 문장으로만 (2절) |
| Dunbar 층 배치 | 중간 | O(n log n) | 중간 ("안쪽 원 = 더 중요") | 사용자가 고르는 원 / 경과 기간 구간 (3절) |

(복잡도 수치 중 Brandes · k-core 는 출처 확인, 나머지는 일반 알고리즘 지식에 기반한 추정 — 5절 참조.)

### Gaps
- Crossley 외 *Social Network Analysis for Ego-Nets* (2015) 와 Perry 외(2018)의 장별 정의 · 권고는 원문을 열지 못해 인용하지 못했다.
- Borgatti 의 제약 재정식화(유효 크기처럼 단순화된 식)는 존재만 확인했고 식은 찾지 못했다.
- Gould–Fernandez 원문(1989, *Sociological Methodology*)의 liaison 정의와 방향 규칙은 2차 출처로만 확인 — 원문 미열람.
- NetworkX constraint 문서 페이지는 DNS 차단으로 열지 못해 p_ij 정규화 식(가중 무방향일 때 (a_ij + a_ji) / Σ_k (a_ik + a_ki))은 원문 대조를 못 했다.

---

## 2. 기록에서 유대 강도 추정 — 사람마다 숫자를 보이지 않고

### Takeaway
고전 이론(Granovetter)과 대규모 실증(Gilbert & Karahalios 2009, Rajkumar 외 2022)은 유대 강도가 **시간(빈도 · 기간 · 최근성) · 친밀 · 상호성 · 구조적 겹침**의 함수라는 데 일치하지만, 2022년 LinkedIn 실험은 그 효과가 **비선형(역U자)이고 측정 방식(공동 지인 수 vs 상호작용 강도)에 따라 달라진다**는 것을 보였다. 앱에서는 기록의 날짜로 최근성 · 빈도 · 기간 · 다중성(유형 수)을 계산하되, 숫자를 사람 옆에 붙이지 않고 **정렬 기준 · 구간 문장 · 기간별 추세**로만 쓴다.

### Cited Findings
- **[고전] Granovetter (1973) 의 네 차원:** 함께 보낸 시간, 정서적 친밀, 강도(intensity), 상호 도움. 후속 연구가 정서적 지지, 구조 변수(네트워크 위상), 사회적 거리(교육 · 계층 등 차이)를 더했다 — [A Survey on Tie Strength Estimation Methods (SciTePress 2022)](https://www.scitepress.org/Papers/2022/108451/108451.pdf), [The Social Bow Tie (arXiv 1710.04177)](https://arxiv.org/pdf/1710.04177) (검색 요약 기준; 두 출처 중 어느 쪽 문장인지 원문 대조 못 함). 시간 차원은 소통의 **기간과 빈도**를 함께 담는다 — 같은 출처.
- **[고전] Gilbert & Karahalios, "Predicting Tie Strength With Social Media," CHI 2009, pp. 211–220:** 2,000개 넘는 소셜 미디어 연결로 모델을 만들어 강한/약한 연결을 **85% 넘는 정확도**로 구분. 예측 못 한 관계는 인터뷰로 조사. 유대 강도 모델이 사생활 설정 · 메시지 전달 · 친구 소개 · 정보 우선순위 설계에 쓰일 수 있다고 주장 — [논문 PDF (Northwestern)](https://collablab.northwestern.edu/CollabolabDistro/nucmc/GilbertKarahalios-PredictingTieStrength-CHI09.pdf), [Northeastern 강의 사본](https://course.khoury.northeastern.edu/is4800sp15/ssl/gilbert.pdf). 후속 요약에 따르면 "한 번 소통하는 행위만으로도 유대 강도가 유의하게 오르고", 교육 수준 차이가 영향을 준다 — [The Social Bow Tie (ar5iv)](https://ar5iv.labs.arxiv.org/html/1710.04177). 확장판: Gilbert & Karahalios 2013, *Foundations and Trends in HCI* 7(3) "Computing and Building Around Tie Strength in Social Media" — [now publishers](https://nowpublishers.com/article/DownloadSummary/HCI-044).
- **[최근] Rajkumar, Saint-Jacques, Bojinov, Brynjolfsson, Aral, "A causal test of the strength of weak ties," *Science* 377(6612):1304–1310 (2022.9):** LinkedIn "알 수도 있는 사람" 알고리즘의 대규모 무작위 실험 여러 건으로 **2천만 명 넘는 사람**의 네트워크에서 약한 연결의 비중을 5년간 무작위로 바꿨다. (1) 유대 강도와 일자리 이동 사이 **역U자** — 약한 연결은 어느 지점까지만 도움 (2) **적당히 약한 연결(공동 지인 수로 측정)** 과 **가장 약한 연결(상호작용 강도로 측정)** 이 일자리 이동을 가장 많이 만들었다 — 즉 측정 방식이 결론을 바꾼다 (3) 디지털 산업에서는 약한 연결이, 덜 디지털한 산업에서는 강한 연결이 이동을 늘렸다 — [Stanford Digital Economy Lab](https://digitaleconomy.stanford.edu/publication/a-causal-test-of-the-strength-of-weak-ties), [Computational Social Science 요약](https://comdig.cssociety.org/2022/09/25/a-causal-test-of-the-strength-of-weak-ties/), [Science News](https://sciencenews.org/?p=3117214). 동반 Perspective(Wang & Uzzi)는 인간관계가 성패에 주는 함의에 질문을 던졌다 — [Gwern 사본 PDF](https://www.Gwern.net/doc/sociology/technology/2022-wang-8.pdf).
- **[고전] 유대의 소멸(decay):** Burt(2000)는 은행가들에게 4년간 매년 "지난 1년 잦고 실질적인 업무 접촉" 상대를 물어 연결의 소멸을 측정했다. 겹침이 적은 약한 연결일수록 끊길 확률이 높았다 — [arXiv 1706.06188](https://arxiv.org/pdf/1706.06188), [arXiv 1102.1753](https://arxiv.org/pdf/1102.1753). 상호적 삼자 관계에 묻힌 쌍은 덜 끊긴다는 명제도 Burt(2000)가 부분적으로 확인했다고 인용된다 — [arXiv 1102.1753](https://arxiv.org/pdf/1102.1753). 개인의 연결 소멸에는 개인의 선택이 작용한다는 경영학 연구도 있다 — [Kleinbaum, Tie Decay Choices (Management Science, PDF)](https://faculty.tuck.dartmouth.edu/images/uploads/faculty/adam-kleinbaum/Kleinbaum_TieDecayChoices.pdf) (본문 미열람).
- **[고전] 정서적 친밀과 접촉 빈도:** Dunbar 연구진(2015)은 쌍별 자기평가 친밀도가 접촉 빈도와 밀접하게 상관한다고 보고 — [arXiv 2205.13980 의 인용 요약](https://www.arxiv.org/pdf/2205.13980) (검색 요약 기준).
- **[고전] 개인의 "사회적 서명(social signature)":** Saramäki 외, *PNAS* 111(3):942–947 (2014). 학생 24명의 18개월 통화 기록 + 설문. 사람마다 상호작용을 alter 들에게 나누는 분포가 독특하고 견고하며, alter 의 **얼굴이 크게 바뀌어도 분포 모양은 유지**됐다(새 사람이 들어오면 옛 사람이 빠지거나 연락이 줄었다). 저자들은 시간 · 인지 · 정서 자원의 유한성으로 해석 — [arXiv 1204.5602](https://arxiv.org/pdf/1204.5602), [Oxford Martin School](https://www.oxfordmartin.ox.ac.uk/publications/persistence-of-social-signatures-in-human-communication).

### Inferences
- **기록에서 바로 나오는 신호(Core 에서 순수 함수로):**
  - 최근성 r = 오늘 − 마지막 공동 기록 날짜 (일)
  - 빈도 f_W = 기간 W(예: 최근 12개월) 안의 공동 기록 수
  - 기간 d = 마지막 기록 − 첫 인연 날짜 (첫 인연은 사람의 속성, ADR-0003)
  - 다중성 = 서로 다른 기록 유형 · 맥락 수 (Granovetter 의 "강도" · Gilbert & Karahalios 의 다차원성에 대응)
  - 공동 지인 수 = 그 사람과 나 모두 아는 alter 수 (Rajkumar 외의 "구조적" 측정에 대응)
  - 소멸 가중 합 w = Σ_k exp(−λ·Δt_k), λ = ln2 / 반감기 h. Burt 의 소멸 함수 연구에 맞춘 일반형 — 반감기 값은 문헌에서 정해진 것이 없으므로 **정답표(`Tools/golden/`)에서 고정한 상수**로 둬야 결정성이 지켜진다.
- **숫자를 보이지 않는 표현 방법:**
  1. **정렬 기준으로만** — "오래 기록이 없는 순" 같은 행동 유도형 정렬(ADR-0004 의 "유대 강도 합성값은 정렬 기준으로만" 과 일치). 정렬 결과에 순번 · 점수 열을 붙이지 않는다.
  2. **구간 문장** — "최근 3개월 안에 기록 있음 / 1년 넘게 기록 없음" 처럼 사람 상세에 범주 문장으로.
  3. **ego 단위 분포** — Saramäki 의 사회적 서명처럼 "내 기록이 사람들에게 어떻게 나뉘는가" 를 **이름 없는 막대**로(상위 몇 명이 기록의 몇 %). 사람 이름을 붙이면 순위가 되므로 분포 모양만.
  4. **변화 중심** — "올해 새로 기록이 생긴 사람 n명, 기록이 끊긴 사람 m명" (사회적 서명의 '얼굴 교체' 를 돌봄 관점으로).
- **"약한 연결 = 덜 중요" 프레임을 피할 근거:** Rajkumar 외는 약한 연결이 일자리 이동에 더 큰 효과를 냈고(역U자), Burt 는 다리가 더 쉽게 끊긴다고 했다. 둘을 합치면 "가볍지만 다른 세계로 이어진 인연은 손을 놓기 쉽다" 는 중립적 · 돌봄형 문장이 나온다 — 평가가 아니라 관리 힌트.
- **기록 편향:** 신호는 "실제 관계" 가 아니라 "내가 적은 범위" 다. Gilbert & Karahalios 도 15% 가량을 못 맞췄고 인터뷰로 이유를 찾았다 — 앱도 "기록 기준" 고지(ADR-0004 ③)와 임계값 미만 안내(④)가 필요하다.

### Gaps
- Gilbert & Karahalios 의 32개 예측 변수 목록과 변수별 가중치(예: 마지막 소통 이후 일수의 기여도)는 PDF 서버 DNS 차단으로 확인하지 못했다.
- Rajkumar 외의 정량 결과(역U자의 정점 위치, 새 연결 · 일자리 수)는 원문을 못 열어 인용하지 못했다.
- 공동 "만남" 기록(통화 · 메시지가 아닌 드문 대면 기록)에 맞춘 소멸 반감기 실증치는 찾지 못했다.

---

## 3. Dunbar 의 층(5–15–50–150)과 비판 — 층을 평가 없이 보여 주는 법

### Takeaway
층 구조(누적 약 5 · 15 · 50 · 150, 바깥으로 500 · 1,500, 비율 약 3)는 통화 · 온라인 자료에서 반복 관찰되지만 **안쪽과 바깥쪽 층만 뚜렷하고 중간 층은 개인차가 크다**. "150" 이라는 상한 자체는 2021년 재분석에서 통계적 근거가 없다는 비판을 받았다. 앱은 층을 "정답 크기" 로 제시하지 말고, **사용자가 직접 원에 배치**하거나 **최근 기록 경과 구간**으로 묶어 보여 주는 것이 안전하다.

### Cited Findings
- **[고전] 층의 크기:** 누적 층의 평균 인원이 약 5 · 15 · 50 · 150 이고(둘째 층에는 평균 10명이 더해져 15), 그 바깥에 500 · 1,500 이 제안된다 — [MacCarron, Kaski, Dunbar, "Calling Dunbar's Numbers," *Social Networks* 2016 (Oxford ORA)](https://ora.ox.ac.uk/objects/uuid:a94d707c-b9c7-4e6c-a9af-3aa18a2e3842/files/rjm214q864), [arXiv 1604.02400](https://arxiv.org/pdf/1604.02400).
- **[고전] 통화 자료 검증(2016):** 통화 빈도를 관계 강도로 보고 업무 · 일회성 통화를 거른 뒤 층 구조의 강한 증거를 찾았지만, **중간 층에서는 큰 변동**이 있었고 이산 층을 찾는 것 자체가 어렵다. 바깥 층의 관계 강도가 안쪽보다 빨리 변한다(Sutcliffe 외 2012, Saramäki 외 2014 인용) — 같은 출처.
- **[고전] 층과 접촉 빈도 · 친밀:** 층마다 접촉 빈도와 정서적 친밀이 뚜렷이 다르다(Roberts 외 2009, Sutcliffe 외 2012) — [arXiv 2205.13980](https://www.arxiv.org/pdf/2205.13980). Sutcliffe · Dunbar · Binder · Arrow (2012, *British Journal of Psychology*)는 층을 약 3배수(5–15–50–150)로 보고, 바깥으로 갈수록 친밀 · 상호작용 빈도가 줄며, 층마다 기능 · 비용-편익이 다르다고 정리했다(유지 비용인 시간은 관계 수에 거의 선형) — [Univ. of Oregon Scholars' Bank 기록](https://scholarsbank.uoregon.edu/items/5421081b-72d9-41af-9935-df60865e3694/full).
- **[최근] Dunbar, "The anatomy of friendship," *Trends in Cognitive Sciences* 22(1):32–51 (2018; 온라인 2017.12.19):** 개인 네트워크의 크기와 위계 구조에 상수성이 많다고 요약 — [Oxford ORA](https://ora.ox.ac.uk/objects/uuid:ec201b93-8447-4d03-bcfc-99d8a3980860). Dunbar 인터뷰: 사회적 노력(상호작용 시간)의 **60%를 15명의 좋은 친구**에게 쓴다 — [MTA 인터뷰](https://mta.hu/english/the-150-of-us-an-interview-with-robin-dunbar-honorary-member-of-mta-about-the-social-network-size-number-of-humans-112469). 대중 요약: 사회적 시간의 최대 40% 가 가장 가까운 5명, 20% 가 15명 층 — [RealKM](https://realkm.com/2016/08/17/new-research-supports-layer-structure-in-social-brain-hypothesis/) (2차 출처, 원 수치 출처 미확인).
- **[최근] 층의 생성 모형:** Tamarit · Cuesta · Dunbar · Sánchez, *PNAS* 115(33):8316–8321 (2018). 관계마다 비용이 다르고 총 노력에 상한이 있다는 가정만으로 층 구조가 나오며, 비용 함수가 선형이면 약 3배 비율도 설명된다. **작은 공동체에서는 층이 뒤집힌 패턴**(안쪽 층이 더 큰)을 예측하고, 다섯 공동체에서 그 증거를 보고 — [Aalto 저장소](https://aaltodoc.aalto.fi/items/80d59d2b-bdcf-4060-b1b0-c25dcb8767a0), [전문 PDF (Zaragoza)](https://zaguan.unizar.es/record/75048/files/texto_completo.pdf).
- **[고전/최근 경계] 온라인 층:** Dunbar · Arnaboldi · Conti · Passarella (2015, *Social Networks*) — 18만 5천 명 넘는 ego 의 Facebook 두 자료 · Twitter 자료에서 양방향 게시 빈도로 연결을 정의. Facebook 은 4층, Twitter 는 5층이 가장 잘 맞고, 층 크기 · 접촉 빈도가 대면 네트워크와 비슷. 세 자료 모두 가장 안쪽에 **약 1.5명**의 층 — [Oxford Neuroscience](https://www.neuroscience.ox.ac.uk/publications/524828), [CNR 기록](https://explore.cnr.it/resource/item/369890).
- **[최근] 비판 — Lindenfors · Wartel · Lind, "'Dunbar's number' deconstructed," *Biology Letters* (2021), DOI 10.1098/rsbl.2021.0158:** 150 은 영장류의 상대 신피질 크기–집단 크기 회귀선의 외삽에서 나왔다. 다른 자료 · 방법으로 재분석하니 베이즈 방법은 평균 69–109, 일반화 최소제곱 계통 방법은 16–42 를 냈고, 95% 신뢰구간이 **4–520 · 2–336** 으로 너무 넓어 "어떤 한 숫자를 특정하는 것은 무의미" 하다고 결론 — [IFFS](https://www.iffs.se/en/publications/journal-articles/dunbar-s-number-deconstructed/), [Stockholm University 보도](https://www.su.se/english/news/articles/2021-05-05-new-study-deconstructs-dunbars-number---yes-you-can-have-more-than-150-friends), [ScienceDaily](https://www.sciencedaily.com/releases/2021/05/210504211054.htm). 보도자료는 구간을 "2–520" 으로 적어 초록 수치와 조금 다르다 — 같은 출처. Lindenfors 는 영장류 사회성이 뇌보다 먹이 · 포식자 같은 요인으로 더 설명된다고 주장 — 같은 출처.

### Inferences
- **비판이 겨냥하는 것과 아닌 것:** Lindenfors 외는 **150 이라는 인지적 상한의 도출 방법**(종간 회귀 외삽)을 반박했다. 개인 자료에서 관찰되는 **층 모양**(안쪽은 작고 자주, 바깥은 크고 드물게)은 통화 · 온라인 · 생성 모형 연구가 따로 지지한다. 앱에는 "층 모양" 만 쓰고 "150명이 한계" 같은 수치 규범은 쓰지 않는 것이 두 쪽 증거와 모두 양립한다.
- **층을 계산으로 정하면 위험한 이유:** 접촉 빈도로 사람을 안쪽/바깥 원에 자동 배치하면 "안쪽 원 = 더 중요한 사람" 으로 읽혀 사실상 등급이 된다. 또 기록은 성기고 편향돼 있다(가족처럼 매일 보지만 기록하지 않는 관계).
- **평가 없이 보이는 세 가지 방법:**
  1. **사용자가 고르는 원** — Hogan 외(2007) 의 위계적 지도처럼 사용자가 직접 원에 둔다(4절). 앱의 판단이 아니라 사용자의 진술.
  2. **경과 구간 원** — 원의 의미를 "중요도" 가 아니라 **"마지막 기록 이후 시간"**(이번 달 · 3개월 · 1년 · 그 이상)으로 정의. 구간 경계는 고정 상수(정답표).
  3. **ego 단위 모양 문장** — "최근 3개월 안에 기록이 있는 사람 12명, 1년 안 48명" 처럼 누적 인원만 말하고 Dunbar 숫자와 비교하지 않는다. 비교가 필요하면 "연구에서는 대략 5·15·50·150 의 모양이 자주 관찰된다(정해진 한계는 아니다)" 정도의 보조 설명.
- **작은 공동체의 뒤집힌 층(Tamarit 외 2018):** 인연이 수십 명뿐인 사용자에게 "바깥 층이 커야 정상" 이라는 암시를 주면 안 된다는 근거.

### Gaps
- 층별 접촉 빈도의 구체 기준(주 1회 · 월 1회 · 연 1회 등)은 Sutcliffe 외(2012) · Dunbar(2018) 원문을 열지 못해 수치로 인용하지 못했다.
- Lindenfors 외(2021)에 대한 Dunbar 측의 공식 반론 논문은 이번 검색에서 찾지 못했다.

---

## 4. 자아 네트워크 시각화 연구 · 개인 네트워크 도구 — 사용자가 얻는 통찰

### Takeaway
연구용 개인 네트워크 도구(EgoNet · VennMaker · Network Canvas)는 거의 모두 **동심원(concentric circles)** 을 뼈대로 하고, 응답자들은 동심원 형식을 가장 선호한다. 동심원의 원 의미를 **사용자가 정하는 것**(친밀도 · 지지)이 연구 표준이며, 사람끼리 아는 사이는 **가까이 두기 · 묶음 원 그리기**로 표현한다. 도구 선택 자체가 끌어내는 네트워크의 크기 · 구성을 바꾼다는 점은 앱 설계에도 경고가 된다.

### Cited Findings
- **[고전] 동심원의 기원:** Kahn & Antonucci (1980)의 **사회적 호송대(social convoy)** — 지지의 정도를 동심원으로 표현. EgoNet 은 동심원 모형의 한 판으로 언급된다 — [Connections 2019 VennMaker 논문 PDF](https://reference-global.com/2/v2/download/article/10.21307/connections-2019.036.pdf).
- **[고전] 위계적 지도 + 참여자 보조 소시오그램:** "A Comparison of Social Network Mapping and Personal Network Visualization," *Field Methods* 19(2):145–162 (2007.5) — 응답자의 개인 네트워크를 **세 개의 동심원**으로 표현하는 위계적 지도. 관련 연구(Carrasco · Hogan · Wellman · Miller)는 원 네 개를 쓰고, 응답자가 alter 를 먼저 자유 나열한 뒤 지도에 배치하고, **서로 아는 사람은 가까이** 두고, 마지막으로 **묶음 둘레에 원을 그리게** 해 구조 정보를 더했다 — [BEBR (Univ. of Florida) PDF](https://bebr.ufl.edu/sites/default/files/A%20Comparison%20of%20Social%20Network%20Mapping%20and%20Personal%20Network%20Visualization.pdf). (저자 표기는 검색 요약에서 확인되지 않음 — Hogan · Carrasco · Wellman 으로 널리 인용되지만 이 세션에서 미확인.)
- **[최근] 응답자 선호와 도구 효과:** Hollstein 연구진의 소시오그램 설계 비교에서 **동심원 형식이 참여자에게 가장 인기**였고, 네트워크를 비교하려면 도표를 소개 · 사용하는 표준화된 대본이 중요하다 — [Person-centered and qualitative approaches to network analysis (arXiv 2402.02942, 2024)](https://arxiv.org/pdf/2402.02942). 응답자는 동심원 도구를 선호하고, **도구 선택이 끌어낸 네트워크의 크기 · 구성에 영향**을 준다 — [Connections 2019 PDF](https://reference-global.com/2/v2/download/article/10.21307/connections-2019.036.pdf).
- **[최근] VennMaker:** 2010년부터 제공. 무료 · 쉬움 · 독학 가능 · 낮은 사양에서 동작해 여전히 쓰인다. Egoweb · OpenEddi 같은 시각적 인터페이스 도구와 Network Canvas 가 대안으로 언급 — [Connections 2019 PDF](https://reference-global.com/2/v2/download/article/10.21307/connections-2019.036.pdf).
- **[최근] Network Canvas (Birkett 외, *Social Networks* 2021):** 무료 · 오픈소스(GPL-3) 묶음. Architect(연구자가 면접 설계) · Interviewer(터치 최적화, 참여자 면접 실행 — Windows · macOS · Linux · **Android · iOS**) · Server(배포 관리 · 내보내기). 참여자 보조 소시오그램이 중심 — [INSNA 소개](https://insna.org/conducting-personal-networks-research-with-network-canvas), [Northwestern SONIC 프로젝트](https://sonic.northwestern.edu/projects-2/netcanvas-2), [Birkett 외 2021 PDF](https://nosh.northwestern.edu/wp-content/uploads/2021/02/1-s2.0-S0378873321000186-main.pdf). 자기 주도 면접 시범 연구에서 **자동 이름 생성과 개인 네트워크 시각화가 자료 수집의 인지 부담을 줄일 잠재력** — [JMIR Formative Research 2021](https://formative.jmir.org/2021/9/e30237/PDF).
- **[최근] R 생태계:** `egor` 패키지는 EgoNet · EgoWeb 2.0 · openeddi 내보내기를 읽고, ego 중심 네트워크를 보는 대화형(shiny) 앱을 포함 — [egor (r-universe)](https://tilltnet.r-universe.dev/api/packages/egor).
- **[최근] 시간에 따른 ego 시각화(시각화 학계):** SpreadLine (2024) — 시간에 따른 ego 중심 영향의 시각화 — [arXiv 2408.08992](https://arxiv.org/pdf/2408.08992). EgoNetCloud (IEEE VIS 2015) — 사건 기반 ego 중심 동적 네트워크 시각화 — [VIS15 미리보기](https://vimeo.com/136206030). (두 논문 모두 본문 미열람, 제목 · 범주만 확인.)

### Inferences
- **연구 도구에서 앱으로 옮길 통찰 세 가지:**
  1. **원의 의미는 사용자가 진술한다** — 연구 도구의 동심원은 응답자가 배치한다. 앱이 계산으로 배치하는 것보다 원칙(사람을 평가하지 않는다)에 맞고, 응답자도 선호한다.
  2. **아는 사이 = 가까이, 모임 = 둘레 원** — 이미 구현된 관계도(빌드 11 · 이슈 15 "먼 칸 무게중심")와 Louvain 모임이 바로 이 표현이다. 숫자 지표 없이도 "내 인연은 세 덩어리, 두 덩어리를 잇는 사람이 두 명" 이 눈으로 보인다.
  3. **시간 축** — SpreadLine · EgoNetCloud 처럼 시점별 조각을 보여 주는 것이 연구 흐름이며, 앱의 "시점 막대 · 묶음의 변화"(빌드 12)와 같은 방향이다.
- **도구 효과의 경고:** 도구가 끌어내는 네트워크 크기를 바꾼다면, 앱의 입력 화면(누구를 함께 적게 하는가)이 곧 그래프 모양을 만든다. "아는 사이" 지표는 **입력 습관의 반영**이라는 고지가 필요하다.
- 연구 도구들은 **분석 숫자를 응답자에게 보여 주지 않는다** — 수치는 연구자에게 간다. 앱 사용자는 응답자이자 연구자이므로, 기본 화면은 응답자용(그림 · 문장), 수치는 꺼 둔 상세용으로 나누는 것이 자연스럽다.

### Gaps
- 개인 네트워크 시각화를 **본인에게 되돌려 보여 줄 때** 어떤 통찰이 유용했는지(성찰 · 행동 변화)를 측정한 사용자 연구는 이번 검색에서 찾지 못했다 (연구 도구 문헌은 자료 수집 품질 중심).
- VennMaker · EgoNet 공식 문서는 검색에 나오지 않아 기능 세부는 2차 출처에 기댔다.

---

## 5. 휴대폰에서의 계산 비용 — 노드 ~5,000 · 연결 ~50,000

### Takeaway
이 규모에서 가장 비싼 지표인 매개 중심성(Brandes)도 비가중 O(nm) ≈ 2.5×10⁸ 단계로, 백그라운드 작업이면 휴대폰에서 충분히 가능하다. k-core 는 O(m), 크기 · 밀도 · 다양성 · 유대 신호는 선형이다. 결정성의 위험은 비용보다 **반복 · 순서 의존 알고리즘(Louvain · PageRank · 고유벡터)** 에 있다.

### Cited Findings
- **[고전] Brandes (2001), "A Faster Algorithm for Betweenness Centrality," *Journal of Mathematical Sociology* 25(2):163–177:** 비가중 **O(nm)** 시간, 가중 **O(nm + n² log n)** 시간, **O(n + m)** 공간. 이전 방법은 Θ(n³) 시간 · Θ(n²) 공간 — [Konstanz 저장소](https://kops.uni-konstanz.de/entities/publication/274409e6-7f4d-48b4-bb64-d794d3912b37). 2001년 기준 이론상 가장 빠른 알고리즘으로 평가 — [Bentert 외, JGAA 2020](https://jgaa.info/index.php/jgaa/article/download/paper543/2434). 경로 비교 기반 알고리즘은 O(nm) 보다 빠를 수 없다는 하한 — [Betweenness Centrality: Algorithms and Lower Bounds (arXiv 0809.1906)](https://arxiv.org/pdf/0809.1906).
- **[고전] k-core 분해:** Batagelj & Zaveršnik — 연결 수에 선형인 **O(m)** 알고리즘(arXiv 2003, *Advances in Data Analysis and Classification* 2011). 일반화 코어는 O(m · max(Δ, log n)) — [arXiv cs/0310049](https://arxiv.org/abs/cs/0310049), [Generalized Cores (arXiv cs/0202039)](https://arxiv.org/pdf/cs/0202039).
- **[고전] 병렬화 참고:** MIT 강의 자료가 Brandes 알고리즘의 병렬 구현을 다룬다(출발점별 독립 BFS) — [MIT 6.886 강의 3-2](https://jshun.csail.mit.edu/6886-s21/lectures/lecture3-2.pdf) (본문 미열람).

### Inferences
- **어림 계산(n = 5,000, m = 50,000):**
  - Brandes 비가중: n·m = 2.5×10⁸ 기본 단계. 가중(공동 기록 수를 거리로): + n² log n ≈ 2.5×10⁷ × 12 ≈ 3×10⁸ → 합 약 5.5×10⁸. 컴파일된 Swift 에서 수 초 안팎으로 추정(실측 아님) — **주 스레드 밖 · 자료 변경 후 캐시**(ADR-0004 결과 절, CLAUDE.md 1절 "본문에서 전원 훑기 금지")가 필수. 출발점 BFS 가 서로 독립이라 `TaskGroup` 병렬화도 가능하지만, 부동소수 합산 순서가 바뀌면 끝자리가 흔들리므로 **출발점별 부분합을 고정 순서로 합산**해야 결정적이다.
  - 실제 앱 규모는 훨씬 작다: 기록한 사람 수백 명이면 n·m ≈ 10⁶ 수준.
  - k-core O(m), 연결 요소 O(n + m), 밀도 · 유효 크기 O(m), ego 제약 O(Σ_j deg(j)) 수준, 다양성 · 유대 신호 O(n + 기록 수) — 모두 즉시.
  - 삼각형 세기(삼자 폐쇄 후보): 일반적으로 O(m·√m) 수준(차수 정렬 기법, 일반 알고리즘 지식 — 출처 미확인) ≈ 1.1×10⁷.
- **큰 모임 기록 주의:** m 은 기록 참여자 수의 제곱으로 커진다. 참여자 100명 기록 하나가 4,950 개 연결을 만든다. 모임 기록을 클리크로 펼치지 말고 **기록–사람 이분 그래프**로 두고 필요할 때만 투영하거나, 참여자 상한을 넘는 기록은 "약한 연결" 로 따로 셈하는 설계가 비용 · 해석 둘 다에 유리하다.
- **결정성 위험 순위:** (1) Louvain — 노드 방문 순서 · 동점 처리에 따라 결과가 바뀜 → 앱은 이미 "고정 차례 + 연결 쪼개기"로 해결(D-30). (2) PageRank · 고유벡터 — 반복 종료 조건이 허용 오차면 기기마다 반복 횟수가 같아도 끝자리가 흔들릴 수 있고, 고유벡터는 끊긴 그래프 · 이분 그래프에서 수렴 문제가 생긴다 → 어차피 제외 대상이라 문제 없음. (3) Brandes · k-core · 밀도 — 정수 연산 또는 고정 순서 합이면 완전 결정적 → 파이썬 정답표(`Tools/golden/`)로 기댓값을 만들어 Swift 와 대조하는 기존 방식에 그대로 맞는다.
- **외부 라이브러리 불필요:** 위 알고리즘은 모두 수백 줄 안의 순수 Swift(Foundation 만)로 구현 가능 → `Packages/Core` 규칙(ADR-0002)과 리눅스 `swift test` 에 맞는다.

### Gaps
- Swift 로 Brandes 를 iPhone 에서 실측한 공개 벤치마크는 찾지 못했다 — 위 시간은 추정이다. 실측은 CI macOS 러너의 앱 테스트에 큰 합성 그래프를 넣어 재는 것이 다음 단계.
- Louvain 의 시간 복잡도(경험적으로 거의 선형)와 PageRank 반복 횟수에 대한 1차 출처는 이번 조사 범위에서 확인하지 않았다.
