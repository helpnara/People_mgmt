# 기본 중심성 너머의 네트워크 과학 기법 — 커뮤니티 · 시간 네트워크 · 링크 예측 · 임베딩/GNN (2018–2026) 과 느린 인연 적용성

> 조사일 2026-10-18. 대상 앱의 현재 구현 (코드에서 확인):
> - `Packages/Core/Sources/Core/Metrics/CommunityDetection.swift` — Louvain, 난수 없는 고정 차례(번호 순 · 이득 같으면 제자리), 끝에 그룹별 연결 조각 쪼개기, 모듈성 문턱 `minimumModularity = 0.3`, 최소 그룹 3명, 나(ego) 제외, 모듈성은 화면에 숫자로 내지 않음.
> - `Packages/Core/Sources/Core/Metrics/TemporalNetwork.swift` — 창 365일, 반감기 182.625일, 진한 선 10개 이상일 때만 탐지, 앞 시점 모임과 **Jaccard 0.3 이상**으로 짝짓기, 크기 변화 0.3, 사건 `new · grew · shrank · merged · split · faded`(문구는 판단하지 않는 말).
> - 정답표 `Tools/golden/generate.py` 는 **표준 라이브러리만 쓰는 손으로 옮긴 파이썬 거울**이다 (networkx 등 의존 없음) — 새 알고리즘도 같은 방식으로 옮겨야 한다.
>
> **조사 한계.** 이번 세션에서 WebFetch 가 arxiv.org · nature.com 등에 DNS 오류로 닿지 않았고 curl 도 프록시 403 이었다. 아래 인용은 **검색 결과의 초록 · 요약 · 2차 문서**에 기댄다. 원문 표 · 수식까지 확인하지 못한 것은 그렇게 적었다. "고전(2018 이전)" 은 따로 표시했다.

## 1. 커뮤니티 탐지 — Louvain 다음은 무엇인가 (Leiden · Infomap · 겹침 · 라벨 전파 · 해상도 · 합의)

### Takeaway
우리 "연결 쪼개기" 패치는 Leiden 이 막는 두 문제 중 **끊긴 그룹(최대 16%)** 만 고치고 **약하게 이어진 그룹(최대 25%)** 은 못 고친다. 5천 명 이하에서 Leiden 의 정제(refinement) 단계는 결정적으로(난수 없이) 구현 가능하고 계산 비용도 무시할 만해 "다음 판" 후보로 적당하다. 겹치는 모임은 Ego-splitting(Epasto 2017)이 우리 Louvain 을 그대로 재사용할 수 있어 가장 현실적이고, 라벨 전파 · Infomap · 클리크 퍼콜레이션은 결정성 · 비용 · 설명 가능성에서 뒤진다.

### Cited Findings
**Leiden (Traag, Waltman, van Eck, Scientific Reports 2019)**
- 실험에서 Louvain 이 낸 커뮤니티의 **최대 25%가 약하게 연결(badly connected)**, **최대 16%가 내부적으로 끊어져(disconnected)** 있었다. 이 수치는 고정 비율이 아니라 실험에서의 상한이다 — [PMC6435756](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6435756/)
- Louvain 은 임의로 나쁘게 연결된 커뮤니티를 낼 수 있고, 반복 실행할수록 끊김 문제가 심해진다 — [PMC6435756](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6435756/)
- Leiden 은 국소 이동과 집약 사이에 **정제 단계**를 넣어 모든 커뮤니티가 내부적으로 연결됨을 증명하며, Louvain 보다 빠르다 — [PMC6435756](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6435756/); [arXiv:1810.08473](https://arxiv.org/abs/1810.08473v2)
- igraph 는 Leiden 을 Traag · van Eck · Waltman 방식으로 제공하지만 문서에 복잡도 · 결정성 언급은 없다 — [python-igraph API](https://python.igraph.org/en/0.11.6/api/igraph.community.html)

**라벨 전파 · Infomap**
- igraph 의 라벨 전파(Raghavan 외, 고전 2007)는 동점을 무작위로 깨고 매 반복 순서를 섞는다. **실행마다 결과가 다를 수 있고 실제로 자주 다르다**고 문서가 경고한다. 복잡도는 비교 연구에서 O(E) — [python-igraph API](https://python.igraph.org/en/0.11.6/api/igraph.community.html); [arXiv:1608.00763](https://arxiv.org/pdf/1608.00763)
- Infomap(Rosvall & Bergstrom, 고전 2008)은 igraph 에서 `trials`(분할 시도 횟수)와 codelength 를 내며, 한 학위논문 표는 비결정적 · O(E) 로 적었다(원 논문 확인 필요라고 표기) — [python-igraph API](https://python.igraph.org/en/0.11.6/api/igraph.community.html); [arXiv:2210.16280](https://arxiv.org/pdf/2210.16280)

**겹치는 커뮤니티**
- **Ego-splitting (Epasto, Lattanzi, Paes Leme, KDD 2017, Google)**: 각 노드의 자아 네트워크(ego-net)를 군집해(국소 단계) 노드를 소속 군집 수만큼의 **페르소나 노드**로 쪼갠 뒤, 페르소나 그래프를 다시 분할(전역 단계)해 겹침 군집을 얻는다. 겹침 문제를 비겹침 분할 문제로 환원 — [Google Research](https://research.google/pubs/ego-splitting-framework-from-non-overlapping-to-overlapping-clusters/); [논문 PDF](https://www.renatoppl.com/papers/egonet.pdf)
- 국소 · 전역 단계 알고리즘은 기존 비겹침 커뮤니티 탐지에서 자유롭게 고를 수 있다(모듈식) — [KIT 석사논문](https://i11www.iti.kit.edu/_media/teaching/theses/ma-wiebigke-19.pdf)
- 저자들은 수백억 간선 그래프로 확장된다고 주장 — [Google Research](https://research.google/pubs/pub46238)
- 클리크 퍼콜레이션(Palla · Barabási · Vicsek, Nature 2007, 고전): 겹치는 커뮤니티를 시간에 따라 추적하며, **큰 집단은 구성원이 바뀔 때 오래가고 작은 집단은 구성이 그대로일 때 오래간다** — [CEU 초록](https://research.ceu.edu/en/publications/quantifying-social-group-evolution/); [arXiv:0704.0744](https://arxiv.org/pdf/0704.0744)

**해상도 한계 · 다중 해상도**
- 모듈성 최적화는 해상도 한계로 작은 모듈(거의 끊어진 클리크조차)을 못 찾을 수 있다(Fortunato & Barthélemy, PNAS 2007, 고전) — [EPJB](https://epjb.epj.org/articles/epjb/abs/2007/05/b06662/b06662.html); [arXiv:1107.1155](https://ar5iv.labs.arxiv.org/html/1107.1155)
- Reichardt–Bornholdt 해상도 γ: γ=1 이 표준 모듈성, γ↑ 이면 잘게 나뉜다. 그러나 Potts 방식도 해상도 문턱이 있고 **γ 를 고를 선험적 원칙이 없다**(Kumpula 외 2007); 다중 해상도 기법도 해상도 한계를 완전히 벗어나지 못한다 — [CEU](https://research.ceu.edu/en/publications/limited-resolution-in-complex-network-community-detection-with-po/); [arXiv:1103.5569](https://pdf.arxiv.org/pdf/1103.5569)

**안정성 · 합의 군집 (Lancichinetti & Fortunato, Sci. Rep. 2012, 고전)**
- 커뮤니티 탐지 결과는 난수 시드 · 초기 조건 · 동점 처리 규칙에 의존한다. 여러 분할을 동시출현 행렬로 합쳐 수렴할 때까지 되풀이하면 안정성과 정확도가 함께 오르며, 어떤 방법에도 씌울 수 있다. 시간 네트워크에서 주제의 탄생 · 소멸 · 분화 추적에 썼다 — [PMC3313482](https://pmc.ncbi.nlm.nih.gov/articles/PMC3313482); [arXiv:1203.6093](https://arxiv.org/pdf/1203.6093)
- 합의 행렬 계산은 비싸서 후속 "Fast consensus"(2019)가 나왔다 — [arXiv:1902.04014](https://ar5iv.arxiv.org/html/1902.04014)

### Inferences
- **연결 쪼개기 vs Leiden.** 쪼개기는 "끊김(16%)" 은 없애지만, 한 다리(bridge) 하나로만 이어진 두 덩어리 같은 "약한 연결(25%)" 은 그대로 남긴다. 또 쪼갠 조각은 원래 이웃 그룹으로 옮겨 가면 모듈성이 오를 수 있는데 쪼개기는 다시 옮기지 않는다. Leiden 의 정제 단계는 각 그룹 **안에서만** 단일 노드에서 출발해 병합하므로 이 두 경우를 다룬다.
- **결정적 Leiden 은 가능하다.** 원 논문의 정제 단계는 무작위 병합(온도 θ)을 쓰지만, θ→0 극한(가장 이득 큰 병합 · 동점은 번호 순)으로 바꾸면 난수가 사라진다. 이는 우리 Louvain 의 "고정 차례" 규칙과 같은 방식이라 손으로 옮긴 파이썬 거울과 글자 단위 대조가 가능하다. 다만 원 논문의 품질 보장(γ-연결 등)은 결정적 변형에서도 "연결됨" 은 유지되지만, 무작위성에 기댄 탐색 이점은 일부 잃는다 — 원문 확인 필요(Gaps).
- **구현 비용 추정.** 현재 Louvain 271줄. 정제 단계 + 정제된 분할 기준 집약은 대략 +120~200줄, 파이썬 거울도 같은 비율. 5천 노드 · 수만 간선에서 Louvain/Leiden 은 한 번 돌기에 간선 수에 비례하므로 휴대폰에서 수십 ms 수준(측정 아님, 복잡도 기반 추정).
- **우리 자료의 특수성 — 기록은 클리크를 만든다.** 참여자 n명인 기록 하나가 n(n−1)/2 개의 무게 1 선(완전 그래프)이 된다. 30명 모임 한 번이 30-클리크를 만들어 (a) 클리크 퍼콜레이션의 k-클리크 열거를 폭발시키고 (b) Louvain 에서 큰 행사 하나가 모임을 지배하게 한다. 공저 네트워크의 고전 처방(Newman 2001, 참여자 n명 기록의 각 쌍에 1/(n−1) 무게)은 이번 조사에서 원문을 확인하지 못했지만, 정답표로 쉽게 대조 가능한 작은 변경이라 검토 가치가 크다.
- **겹침의 필요성.** 개인 인맥에서 "대학 친구이면서 지금 직장 동료" 는 흔하다. Ego-splitting 은 국소 단계에 연결 조각(또는 우리 Louvain)을, 전역 단계에 우리 Louvain/Leiden 을 그대로 쓸 수 있어 새 알고리즘이 거의 없다. 비용은 Σ(차수²) 수준의 ego-net 처리 — 큰 모임 클리크가 있으면 커진다. 화면에서 한 사람이 두 묶음에 동시에 그려져야 하므로 배치(FR) · 범례 설계 비용이 알고리즘보다 크다.
- **라벨 전파는 결정적으로 만들면(고정 순서 · 고정 동점 규칙) 진동 · 단일 거대 라벨 수렴 문제가 생기기 쉽다(경험적 지식, 출처 미확인).** 우리 정답표 방식과 맞지 않아 건너뛴다.
- **Infomap** 은 흐름(랜덤 워크) 기반이라 방향 · 흐름이 의미 있는 그래프에 강점이 있다. 우리 그래프는 무방향 공동참여라 모듈성과 결과 차이가 설명 비용을 정당화하지 못한다. 코드 길이(맵 방정식 · 다층 탐색)도 Louvain 의 몇 배.
- **합의 군집의 쓸모는 "안정성" 이 아니라 "불확실한 사람 표시".** 우리 알고리즘은 이미 결정적이라 같은 입력엔 같은 답이지만, 기록 한 건 추가로 그룹이 크게 바뀔 수 있다. 노드 순서를 몇 가지(이름 순 · 역순 · uuid 순) 돌려 동시출현 비율이 낮은 사람을 "경계에 있는 사람" 으로 옅게 보여 줄 수 있다. 다만 5천×5천 행렬(2,500만 칸)은 휴대폰에 무거우므로 **간선 위에서만** 동시출현을 세야 한다(Fast consensus 의 발상). 점수처럼 보이지 않게 숫자를 숨겨야 한다.
- **해상도.** γ 선택 원칙이 없다는 결과는, 기존 검토의 "크게 묶기 / 보통 / 잘게 나누기" 3단 선택(γ 값 숨김)이 학계 입장과도 맞는 설계임을 뒷받침한다.

### Gaps
- Leiden 원문의 정확한 보장 목록(γ-separated, γ-connected, subpartition γ-dense, uniformly γ-dense, subset optimal)과 그 각각이 θ→0 결정적 변형에서도 성립하는지 — 원문 PDF 에 접근하지 못해 확인 못 함.
- Ego-splitting 원 논문의 국소 단계 권장 알고리즘(연결 조각 vs 다른 방법)과 수치 결과 — 초록 수준만 확인.
- 링크 커뮤니티(Ahn · Bagrow · Lehmann, Nature 2010, 고전)는 이번에 출처를 찾지 못했다.
- 5천 노드에서의 실제 아이폰 실행 시간 측정치는 없다(복잡도 기반 추정뿐).

## 2. 시간 네트워크 — 진화하는 모임 추적 · 관계 감쇠 · 버스트 · 변화점 · 사건 분류

### Takeaway
우리 방식(시점마다 독립 탐지 → Jaccard 짝짓기)은 Rossetti & Cazabet(2018)의 분류에서 가장 단순한 "즉시 최적(instant-optimal)" 계열이며 Greene 외(2010)의 방식과 사실상 같다. 개선은 알고리즘 교체보다 **(1) 대칭 Jaccard 대신 방향 있는 포함도(GED)로 grew/merged 를 가르기, (2) "다시 모임(resurgence)" · "그대로(continue)" 사건 추가, (3) 짝짓기 문턱(우리 0.3 vs 문헌 0.1) 재검토** 가 값싸고 효과가 크다. 버스트 지수 · 베이지안 변화점 탐지는 우리 자료 밀도(사람당 분기 기록 몇 건)에서 통계적으로 불안정하다.

### Cited Findings
**동적 커뮤니티 탐지 서베이 · 매칭**
- Rossetti & Cazabet, "Community Discovery in Dynamic Networks: A Survey", ACM Computing Surveys 51(2):35 (2018) — 상위 3분류(동적 커뮤니티 정의에 따라)로 접근법을 나눈다 — [arXiv:1707.03186](https://arxiv.org/pdf/1707.03186); [dblp](https://dblp.org/pid/74/8877)
- Cazabet & Rossetti, "Challenges in Community Discovery on Temporal Networks" (Temporal Network Theory, Springer, 185–202) — [arXiv:1907.11435](https://arxiv.org/pdf/1907.11435)
- **Greene, Doyle, Cunningham (ASONAM 2010)**: 스냅숏마다 정적 알고리즘으로 커뮤니티를 찾고, 인접 스냅숏 사이를 **Jaccard 가 사용자 지정 문턱 이상이면 짝짓기(다대다 허용)**. 각 커뮤니티를 진화 사건의 연쇄로 기술; 이동통신 월별 통화 그래프로 평가 — [Google Research](https://research.google/pubs/tracking-the-evolution-of-communities-in-dynamic-social-networks/); [arXiv:2302.12759](https://arxiv.org/pdf/2302.12759)
- 후속 비교 연구와 `lifecycles` 라이브러리는 **문턱 0.1 이 원 논문의 최선 결과**라며 기본값으로 둔다(2차 출처 — 원문 미확인) — [arXiv:2302.12759](https://arxiv.org/pdf/2302.12759); [lifecycles docs](https://lifecycles.readthedocs.io/en/latest/reference/algorithms/event_analysis/lifecycles.algorithms.event_graph_greene.html)
- **GED (Bródka 외, 2012~)**: 사건 7종 — forming · dissolving · continuing · growing · shrinking · merging · splitting. 핵심은 **포함도(inclusion)** — 한 그룹 구성원이 다른 그룹에 얼마나 들어 있는가(양) + 중요한 구성원이 얼마나 넘어갔는가(질, 중심성 가중). 문턱 α, β 는 실험상 50~100% 범위 권장; 한 정식화에서 dissolving 은 모든 다음 그룹과 양방향 포함도 ≤10% — [arXiv:1207.4297](https://arxiv.org/pdf/1207.4297); [arXiv:1301.1534](https://arxiv.org/pdf/1301.1534)
- Palla 외(2007, 고전)는 클리크 퍼콜레이션으로 겹침 커뮤니티를 추적했고, 큰 집단은 구성 변화가 있어야, 작은 집단은 구성이 고정돼야 오래간다 — [CEU](https://research.ceu.edu/en/publications/quantifying-social-group-evolution/)
- 합의 군집은 시간 네트워크에서 주제의 탄생 · 소멸 · 분화를 추적하는 데 쓰였다 — [PMC3313482](https://pmc.ncbi.nlm.nih.gov/articles/PMC3313482)

**관계 감쇠 · 이탈(turnover)**
- Kossinets & Watts (Science 2006, 고전): 대학 구성원 약 43,500명, 1학년도 이메일 헤더. 평균 네트워크 성질은 평형에 다가가지만 **개인 수준 성질은 불안정**. 이메일 자료는 관계 종료를 기록하지 않으므로 일정 기간 메시지가 없으면 끝났다고 가정하는 것이 관행 — [citedrive](https://www.citedrive.com/en/discovery/empirical-analysis-of-an-evolving-social-network); [U-Mich 강의자료](https://open.umich.edu/sites/default/files/downloads/SI508-F08-Week11.pdf)
- 군집을 잇는 다리(bridge) 관계는 다른 관계보다 빨리 감쇠한다(Burt 2002 인용) — [arXiv:1102.1753](https://ar5iv.labs.arxiv.org/html/1102.1753)
- Kleinbaum (Management Science): MBA 반 재배정 자연실험 — 사람들은 가치 있는 관계, 상호적 관계, **사회적으로 배태된(공통 지인이 있는) 관계**를 유지한다 — [Kleinbaum PDF](https://faculty.tuck.dartmouth.edu/images/uploads/faculty/adam-kleinbaum/Kleinbaum_TieDecayChoices.pdf)
- "Temporal patterns behind the strength of persistent ties" (2017) — [arXiv:1706.06188](https://arxiv.org/pdf/1706.06188)
- **사회적 서명(social signature)** (Saramäki 외, PNAS 2014): 18개월, 학교→대학/직장 이행기. 개인의 접촉 분배 모양은 **상대(alter)가 크게 바뀌어도 유지**된다 — 시간이라는 유한 자원의 결과로 해석. 2018 후속(통화 vs 문자)도 같은 결론 — [Oxford Martin](https://www.oxfordmartin.ox.ac.uk/publications/persistence-of-social-signatures-in-human-communication); [Applied Network Science 2018](https://link.springer.com/10.1007/s41109-018-0065-4)

**버스트 · 변화점**
- 버스트 지수 B = (σ−μ)/(σ+μ) (Goh & Barabási, EPL 2008, 고전): 규칙적 −1, 포아송 0, 극단적 버스트 +1. 사람 활동은 기억 계수 M ≈ 0 이라 B 는 대부분 두꺼운 꼬리 사건간격 분포를 반영. **B 는 유한 크기 효과에 강건하지 않을 수 있다** — [arXiv:physics/0610233](https://arxiv.org/pdf/physics/0610233); [PRE 92.022814](https://acris.aalto.fi/ws/portalfiles/portal/26798917/PhysRevE.92.022814.pdf)
- Peel & Clauset (AAAI 2015): 일반화 계층 랜덤 그래프 + 베이지안 가설검정으로 네트워크 대규모 구조의 변화점을 온라인 탐지; 두 소셜 네트워크에서 알려진 외부 충격과 일치 — [AAAI OJS](https://ojs.aaai.org/index.php/AAAI/article/view/9574)

### Inferences
- **우리 위치.** 독립 스냅숏 + 매칭 = 즉시 최적 계열. 장점: 단순 · 결정적 · 정답표 대조 쉬움. 알려진 약점: 스냅숏마다 탐지가 독립이라 실제 변화 없이도 경계 사람이 오가며 가짜 사건(grew/shrank 깜빡임)이 생긴다. 완화책은 (a) 분기 창이 12개월로 겹치므로 이미 부분적으로 매끄럽다, (b) 앞 시점 분할을 Louvain 의 **초기값**으로 주는 "시간 절충(temporal trade-off)" 방식 — 결정성 유지, 코드 몇십 줄. (b) 는 3분류 중 두 번째 계열에 해당한다는 서베이 구조와 맞지만, 서베이 원문에서 이 정확한 명칭 · 예시를 확인하지는 못했다.
- **Jaccard 의 한계.** Jaccard 는 대칭이라 "작은 모임 A 가 큰 모임 B 에 흡수" 와 "B 가 조금 바뀜" 을 잘 가르지 못한다. GED 식 **방향 있는 포함도** |A∩B|/|A| 와 |A∩B|/|B| 를 같이 쓰면: 둘 다 높음 = 그대로, 앞→뒤만 높음 = 합쳐짐/커짐, 뒤→앞만 높음 = 나뉨/줄어듦으로 판정이 명확해진다. 정답표로 옮기기 쉽다. GED 의 "질" 항(중심성 가중)은 **사람을 중요도로 가중하는 것이라 ADR-0004 에 걸리므로 빼고 양 항만 쓴다.**
- **문턱 0.3 vs 0.1.** Greene 원 논문 최선값이 0.1 이라는 2차 보고가 맞다면, 우리 0.3 은 짝을 덜 지어 "새로 생김 + 최근 기록 없음" 쌍을 과다 생성할 수 있다. 개인 인맥은 모임이 작아(3~15명) 한두 명 변동이 Jaccard 를 크게 흔든다. 정답표 견본으로 0.1/0.2/0.3 을 비교하는 실험이 값싸다.
- **사건 분류 보강 제안.** 문헌 사건 집합(GED 7종, Greene/Palla 의 탄생 · 소멸 · 병합 · 분할 · 확장 · 수축, 서베이의 resurgence)에 비해 우리에게 빠진 것: ① **그대로(continue)** — 변화 없음을 명시하면 "아무 일 없음" 과 "판정 불가" 를 가른다, ② **다시 모임(resurgence)** — 몇 분기 기록이 없던 모임이 돌아옴(동창 모임 재개 등). 개인 인맥 앱에서 정서적 가치가 가장 큰 사건이다. 구현은 사라진 모임을 N 분기 동안 "잠든 모임" 으로 보관하고 새 모임과 포함도 비교. 문구는 판단 없는 말("다시 함께한 기록이 생겼습니다")로. resurgence 가 Rossetti & Cazabet 서베이의 공식 사건명이라는 점은 원문을 열지 못해 미확인(Gaps).
- **감쇠 모형.** 우리 6개월 반감기 지수감쇠 + 12개월 창은 연속 감쇠 모형의 이산 근사다. 문헌(Kossinets–Watts)도 "일정 기간 무접촉 = 종료" 관행을 쓰므로, 창이 이를 대신한다. Kleinbaum 결과는 **공통 지인이 있는 관계가 덜 감쇠**함을 보여, 개인별 "연락이 뜸해짐" 을 보여 줄 때 혼자 떨어진 관계를 더 일찍 알릴 근거가 된다 — 다만 이것은 사람별 신호이므로 점수 · 순위가 아닌 "최근 기록 없음" 사실 문구로만.
- **사회적 서명 · 이탈(churn).** "나의 인연 분배 모양은 유지되며 사람은 바뀐다" 는 결과는 분기별 **나 전체에 대한** 요약(이번 분기 새로 함께한 사람 수 · 다시 함께한 사람 수 · 쉬어 간 사람 수)이 관계 연구와 맞는 정당한 지표임을 뒷받침한다. 이는 나를 비추는 지표라 ADR-0004 와 충돌하지 않는다.
- **버스트 · 변화점은 보류.** B 는 사건 간격이 수십 개 이상일 때 의미가 있는데, 사람당 기록은 연 몇 건이다. 유한 크기에 약하다는 지적까지 있어 사람별 B 는 잡음이다. 나 전체의 활동량 변화점은 Peel–Clauset 같은 모형 대신 **분기 기록 수의 단순 비교**로 충분하고, 그마저 "판단" 으로 읽히지 않게 사실 문구로.

### Gaps
- Rossetti & Cazabet 서베이 원문의 사건 목록 정의(특히 resurgence)와 3분류의 정식 명칭 — PDF 접근 실패로 직접 확인 못 함.
- Greene 원 논문의 "0.1 최선" 을 1차 출처로 확인 못 함(2차 출처 둘이 일치).
- "relationship trajectory"(관계 궤적) 를 직접 다룬 2018–2026 개인 인맥 연구는 이번 검색에서 찾지 못했다.
- 2018–2026 의 MONIC 계열(클러스터 전이) 후속 연구는 검색하지 않았다.

## 3. 링크 예측 — "서로 알 수도 있는 사람" · "소개해 보지 않은 두 사람" 제안

### Takeaway
작은 개인 그래프에서는 공통 이웃(CN) · Adamic–Adar · 자원 할당(RA) 같은 국소 지수가 정확도 · 비용 · 설명 가능성 모두에서 충분하며, 최신 GNN 도 이 휴리스틱을 일관되게 넘지 못한다는 2023–2024 결과가 있다. 다만 개인 일지 앱에서 링크 예측은 "추천" 이 아니라 **입력 보조**("두 분이 기록 3건에 함께 나왔어요 — 아는 사이로 이을까요?")로만 써야 하며, 점수를 보이지 않고 자동으로 선을 만들지 않는 것이 윤리 · ADR-0004 와 맞는다. "소개해 보지 않은 X 와 Y" 제안은 제3자에 대한 추론을 앱이 먼저 꺼내는 것이라 건너뛰기를 권한다.

### Cited Findings
- Zhou · Lü · Zhang (EPJ B 71, 2009, 고전): 국소 유사도 9종을 실제 네트워크 6개로 비교 — **CN 이 전체 최상, Adamic–Adar 2위**; 자원 할당 과정에서 착안한 새 지수(RA)는 CN 보다 정확. 가장 가까운 이웃 정보만 쓰면 **많은 쌍이 같은 점수**가 되어 다음 이웃 정보를 쓰는 지수를 추가 설계 — [EPJB](https://epjb.epj.org/articles/epjb/abs/2009/20/b090010/b090010.html); [arXiv:0901.0553](https://arxiv.org/abs/0901.0553)
- Lü & Zhou (EPL 2010) 가중 네트워크 후속에서는 RA 가 전체 최상으로 보고됨 — 위 검색 요약(원문 미확인) — [arXiv:0901.0553](https://ar5iv.arxiv.org/html/0901.0553)
- RA(x,y) = Σ_{z∈공통이웃} 1/|Γ(z)| — 이웃이 많은 공통 이웃일수록 덜 기여. 공통 이웃은 단백질 네트워크보다 **소셜 네트워크에서 더 좋은 예측자** — [arXiv:1411.5118](https://arxiv.org/pdf/1411.5118); [arXiv:1010.0725](https://arxiv.org/pdf/1010.0725)
- 2023 서베이: 국소 유사도 지수는 전역 지수 · 기계학습보다 덜 정확하지만 빠르고, 하이퍼파라미터 조정이 거의 없으며, 분야가 다른 그래프 사이에 그대로 옮겨진다 — [arXiv:2306.12970](https://arxiv.org/pdf/2306.12970)
- Li 외 (NeurIPS 2023 Datasets & Benchmarks): GNN 링크 예측 평가의 함정 — 기준선 성능 과소보고, 통일되지 않은 분할 · 지표, **너무 쉬운 음성 표본**. 어려운 음성 표본을 휴리스틱으로 뽑는 HeaRT 평가 제안 — [NeurIPS 2023](https://proceedings.neurips.cc/paper_files/paper/2023/hash/0be50b4590f1c5fdf4c8feddd63c4f67-Abstract.html)
- Delarue · Bonald · Viard (2024, "Link Prediction Without Learning"): 단순 위상 휴리스틱이 GNN 의 경쟁력 있는 대안으로 꾸준히 나타나며, GNN 이 링크 예측의 성능 기준을 일관되게 세우지 못한다; 비신경망 모형이 큰 계산시간 이점과 함께 SOTA GNN 을 앞선다고 보고(초록 수준) — [HAL hal-04643971](https://hal-bioemco.ccsd.cnrs.fr/NOS/hal-04643971v1)
- Kossinets & Watts: 같은 수업을 듣는 사람이 **공통 지인이 있으면** 이메일을 시작할 확률이 약 3배 — 삼자 폐쇄(triadic closure)의 실증 — [U-Mich 강의자료](https://open.umich.edu/sites/default/files/downloads/SI508-F08-Week11.pdf)

**프라이버시 · 윤리**
- 친구 찾기용 연락처 업로드로 네트워크가 **비회원** 정보를 추론할 수 있다; 2013년 페이스북 버그로 약 600만 명의 이메일 · 전화번호가 친구들에게 노출되었고, 일부는 본인이 입력한 적 없는 번호가 친구들의 연락처 업로드에서 수집되어 있었다 — [Heidelberg 보도자료](https://uni-heidelberg.de/presse/news2012/pm20120430_netzwerke_en.html); [ar5iv:1409.6197](https://ar5iv.arxiv.org/html/1409.6197)
- Garcia (Science Advances 2017): 서비스 사용자가 준 자료로 **비사용자의 성적 지향 · 연애 상태를 예측**할 수 있고, 예측력은 네트워크 크기와 연락처 공유 의향에 따라 커진다 → **네트워크화된 프라이버시** 패러다임 필요. 저자들은 섀도 프로필이 실제 존재함을 보인 것은 아니라고 명시 — [PMC5544396](https://pmc.ncbi.nlm.nih.gov/articles/PMC5544396); [EPJ Data Science 2018](https://doaj.org/article/0b7f8f51bde24283b465e8d36a047b1c)

### Inferences
- **정확도는 문제가 아니다.** 사용자의 그래프는 사용자가 직접 넣은 것이라 "숨은 링크" 의 기저율이 높다 — 함께 기록에 나온 두 사람이 서로 모른다는 건 드물다. 이 경우 예측이 아니라 **추론(같은 기록 공동 참여 = 거의 확실히 서로 앎)** 이다. 기존 검토가 "막히는 것은 입력" 이라 했으므로, 링크 예측의 가장 큰 가치는 "아는 사이 잇기" 입력을 빠르게 채우는 **후보 목록**이다.
- **권장 형태.** ① 근거가 사실인 것만: "기록 N건에 함께 나왔습니다", "같은 사람이 두 분을 소개했습니다"(공통 소개자). ② 점수 · 퍼센트 · 순위 숨김(정렬은 내부적으로 CN 개수 → 이름 순, 결정적). ③ 자동 생성 금지, 한 번 "아니요" 한 쌍은 다시 묻지 않기(저장 필요). ④ RA/AA 는 동점 깨기 용도로만 내부 사용 가능 — 그러나 정답표 대조 대상이 늘므로 CN 만으로 시작해도 충분.
- **"소개해 보지 않은 X 와 Y"(중매형 제안)는 건너뛴다.** 이유: (a) 앱이 제3자 두 명의 관계 가능성을 먼저 꺼내 사용자 행동(소개)을 유도 — 일지가 아니라 사교 최적화 도구가 됨, (b) 두 사람의 동의 없는 추론이라는 네트워크화된 프라이버시 문제(Garcia), (c) "이 사람은 소개할 가치가 있다" 는 함의가 ADR-0004(사람 점수화 금지)에 가깝다.
- **기기 내 프라이버시.** 앱은 네트워크 요청이 없으므로 PYMK 식 누출 경로(서버 · 연락처 업로드)가 원천적으로 없다. 남는 위험은 **화면 노출**: 휴대폰을 남에게 보여 줄 때 "A 와 B 는 서로 알 수도 있어요" 같은 추론 문장이 보이는 것. 후보 목록은 사용자가 연 화면에서만 보이게.
- **Katz** 같은 전역 지수는 경로 수를 감쇠 합산해 정확도는 오를 수 있지만 행렬 연산 · 감쇠 β 튜닝이 필요하고, 우리 용도(입력 보조)에선 이득이 없다.

### Gaps
- 개인 일지/CRM 맥락의 링크 예측 UX · 윤리를 직접 다룬 사용자 연구는 찾지 못했다.
- Facebook "알 수도 있는 사람" 기능 자체에 대한 1차 문서 · 규제 조치는 이번 검색에서 나오지 않았다.
- Katz 지수의 원 출처(Katz 1953) · 최근 비교 수치는 검색하지 않았다.

## 4. 그래프 임베딩 · GNN · 그래프 파운데이션 모델 — 휴대폰 위 소규모 자료에서의 현실적 가치

### Takeaway
과하다. 우리 그래프는 사용자 한 명의 수십~수천 노드, 정답 라벨 없음, 학습 자료 없음이며, 결과가 결정적이고 파이썬 정답표로 대조돼야 한다. node2vec(무작위 보행) · GraphSAGE/GAT(학습) · 그래프 파운데이션 모델(사전학습 대형 모델) 모두 이 요건을 깬다. 링크 예측에서도 휴리스틱이 GNN 과 대등하다는 2023–2024 평가 결과가 있다.

### Cited Findings
- 그래프 파운데이션 모델 서베이(2023, 2025 개정): GNN 기반 · LLM 기반 · GNN+LLM 기반 3분류 — [arXiv:2310.11829](https://arxiv.org/html/2310.11829v4)
- "Graph Foundation Models: A Comprehensive Survey" (2025-05): 백본 · 사전학습 · 적응의 모듈식 틀, 일반화 범위로 범용 · 과제특화 · 도메인특화 분류 — [arXiv:2505.15116](https://arxiv.org/html/2505.15116v1)
- GNN 링크 예측 평가의 함정(쉬운 음성 표본 등)으로 GNN 우위가 과대평가되어 왔다 — [NeurIPS 2023](https://proceedings.neurips.cc/paper_files/paper/2023/hash/0be50b4590f1c5fdf4c8feddd63c4f67-Abstract.html)
- 단순 위상 휴리스틱이 GNN 의 경쟁력 있는 대안 — [HAL hal-04643971](https://hal-bioemco.ccsd.cnrs.fr/NOS/hal-04643971v1)
- Core ML 실사용 보고: 변환한 PyTorch 모델이 아이폰 15 Pro Max 에서 CPU 로만 돌았다(지원 안 되는 연산이 GPU/뉴럴 엔진을 비켜 가게 함, 연산명 미상) — [Apple 개발자 포럼](https://origin-devforums.apple.com/forums/profile/AriJR)
- 일반론: iOS 는 앱이 메모리 절반 이상을 쓰면 종료할 가능성이 높다는 기사(2차, 출처 품질 보통) — [unite.ai](https://www.unite.ai/?p=361988)

### Inferences
- **학습할 것이 없다.** GNN 은 라벨(예: 알려진 모임 · 알려진 선)과 많은 그래프에서 배울 때 가치가 있다. 우리는 그래프 1개 · 라벨 0. 사용자 간 연합학습은 "네트워크 요청 0" 원칙에 반한다. 사전학습 파운데이션 모델을 기기에 싣는 것은 앱 크기 · 메모리 · 결정성 · 설명 가능성에서 모두 손해.
- **node2vec** 는 학습 없이 쓸 수 있지만 무작위 보행 + skip-gram 이라 같은 입력에 같은 결과를 내려면 난수 시드 고정 + 부동소수 순서까지 맞춰야 하고, 파이썬 거울(표준 라이브러리만)로 글자 단위 대조가 사실상 불가능하다. 얻는 것(유사 사람 찾기 · 군집)은 Louvain · CN 이 이미 설명 가능한 형태로 준다.
- **임베딩 기반 "비슷한 사람" 은 사람 간 유사도 점수**라 ADR-0004 위험이 크다.
- **레이아웃 대안으로서의 임베딩**(스펙트럴 · UMAP 등)도 FR + Barnes–Hut 가 이미 5천 노드에서 충분하므로 이득이 적다.
- **LLM + 그래프**(기기 내 Apple Intelligence 류 모델로 모임 이름 짓기 등)는 "모임 이름 제안" 정도에 쓸 여지가 있으나, 현재 결정적 규칙(소속 → 태그 → 알게 된 경로 최빈값)이 정답표로 검증 가능하므로 대체 이유가 없다. 이는 이 조사 범위의 추론이다.

### Gaps
- Core ML 의 희소 텐서 · scatter/gather(메시지 패싱) 연산 지원 현황은 Apple 1차 문서로 확인하지 못했다.
- 1천~5천 노드 규모 단일 그래프에서 GNN 과 휴리스틱을 직접 비교한 벤치마크는 찾지 못했다.
- node2vec(Grover & Leskovec 2016) · GraphSAGE(2017) · GAT(2018) 원 논문은 이번에 따로 검색하지 않았다(널리 알려진 고전급 기법으로만 언급).

## 5. 개인 인맥에 맞는 다른 최근 SNA 개념 — 다층 · 동질성/다양성 · 이탈 · 지지망 · 부호 네트워크 · 던바 층

### Takeaway
가장 잘 맞는 것은 **다층(multiplex) 관점**(함께한 기록 · 소개 · 아는 사이 · 같은 소속을 층으로 다루기)과 **나 중심 구성 다양성(Blau/IQV, 관계 유형 · 알게 된 경로 분포)** 이다. 둘 다 "나의 인연을 어떻게 돌보고 있는가" 에 답하고 사람을 점수화하지 않는다. 던바 층 · 부호 네트워크는 사람을 등급 매기거나 부정적 관계를 기록하게 해 원칙과 충돌한다.

### Cited Findings
- **다층 네트워크** (Kivelä 외, Journal of Complex Networks 2(3):203–271, 2014, 고전급 리뷰): 실제 시스템은 여러 종류의 관계를 동시에 가지며, 다층 · 다중(multiplex) · 상호의존 네트워크 용어를 통일하는 틀과 사전을 제시 — [arXiv:1309.7233](https://arxiv.org/abs/1309.7233); [UCLA PDF](https://www.math.ucla.edu/~mason/papers/multilayer_review-published.pdf)
- 다층 소셜 네트워크에서의 집단 추출 · 분석 방법(Bródka 계열) — [arXiv:1612.02377](https://arxiv.org/pdf/1612.02377)
- **자아 중심 네트워크 분석 교과서** Perry · Pescosolido · Borgatti (Cambridge 2018) — [Indiana Univ.](https://sociology.indiana.edu/research/books/2018-egocentric-network-analysis.html)
- 구성(composition) 지표: alter 종류의 빈도 · 중심 경향, 그리고 이질성 지표 **Blau/Herfindahl, Agresti IQV**; 동질성은 **E-I 지수** — [Borgatti 강연자료](https://www.slideshare.net/slideshow/keynote-borgatti/11176884)
- 2020 Network Science 논문은 ego 네트워크 크기 · 밀도와 함께 **구성(다양성)** 을 결과 변수로 사용 — [Network Science 2020](https://doi.org/10.1017/NWS.2020.6)
- **던바 층** 약 5 · 15 · 50 · 150 (각 층이 약 3배); 페이스북 · 트위터 ego 네트워크도 4~5층 구조로 오프라인 값과 매우 가깝다(2015); 휴대전화 연구의 누적층 평균 4.1 · 11.0 · 29.8 · 128.9. 150 은 평생이 아니라 **한 시점**의 수 — [Oxford 2015](https://www.neuroscience.ox.ac.uk/publications/524828); [arXiv:1604.02400](https://arxiv.org/pdf/1604.02400v1); [MIT Tech Review](https://technologyreview.com/s/601369/your-brain-limits-you-to-just-five-bffs)
- 사춘기 동안 층 구조의 변화 — [Sci. Rep. 2021](https://link.springer.com/10.1038/s41598-021-90984-z)
- 사회적 서명: 사람이 바뀌어도 분배 모양은 유지(이탈 연구의 근거) — [Oxford Martin](https://www.oxfordmartin.ox.ac.uk/publications/persistence-of-social-signatures-in-human-communication)

### Inferences
- **다층.** 우리 선 원천(함께한 기록 · 소개 · 아는 사이 · 같은 소속)은 이미 다층이다. 다층 커뮤니티 탐지(층별 결합 모듈성)까지 갈 필요는 없고, **층 켜고 끄기 + 층마다 따로 탐지한 결과 비교**("기록으로 본 묶음 vs 아는 사이로 본 묶음")가 설명 쉽고 결정적이다. 같은 소속 층을 탐지에서 빼는 기존 결정(되풀이 방지)은 다층 관점에서도 옳다 — 속성(소속)과 관계(함께함)를 섞지 않는 것.
- **구성 다양성.** 관계 유형 · 알게 된 경로 · 소속 분포에 Blau 지수(1−Σp²)를 쓰면 "최근 1년 함께한 사람의 알게 된 경로가 얼마나 다양한가" 같은 **나에 대한** 지표가 된다. 숫자 대신 막대 분포 + 중립 문장으로. 단일 숫자로 내면 "다양성 점수" 가 되므로 기존 원칙대로 분포만.
- **E-I 지수 · 동질성**은 alter 속성(나이 · 성별 등)이 필요한데 우리 자료에 없고 넣을 이유도 없다 — 건너뛴다.
- **던바 층은 건너뛴다.** 사람을 "가장 가까운 5명" 등으로 등급 나누는 것은 순위표와 같다(ADR-0004). 집계 형태("최근 3개월 자주 함께한 사람 수") 정도만 가능.
- **이탈(churn).** 분기 시점 조각이 이미 있으므로 "새로 함께한 · 다시 함께한 · 쉬어 간 사람 수" 를 나 전체 집계로 보여 줄 수 있다. 사회적 서명 결과가 근거.
- **지지망 지도(social support mapping)** 는 "누구에게 어떤 도움을 받는가" 를 묻는 설문형 자료가 필요 — 앱의 기록 유형 확장 없이는 불가. 이번 조사에서 2018–2026 출처를 찾지 못했다.
- **부호(signed) 네트워크**(구조적 균형)는 "사이가 나쁨" 을 기록해야 하는데, 실존 인물에 대한 부정적 기록은 민감 정보이고 앱 정신(인연을 기록)과 맞지 않는다 — 건너뛴다.

### Gaps
- 부호 네트워크 · 구조적 균형 최근(2018–2026) 문헌은 이번에 검색하지 않았다.
- 사회적 지지망 측정(예: 지지 유형별 이름 생성기)의 최근 문헌을 찾지 못했다.
- Blau/IQV 의 정확한 정규화 식은 교과서 원문에서 확인하지 못했다(Blau = 1−Σp² 는 널리 알려진 정의로 적음).

## 6. 종합 — 기법별 판정표

### Takeaway
지금 채택할 것은 **값싸고 결정적이며 파이썬 거울로 대조 가능한** 개선 네 가지: 방향 있는 포함도 매칭 + 사건 보강(그대로 · 다시 모임), 짝짓기 문턱 재검토, 공동참여 무게 1/(n−1) 검토, 공통 이웃 기반 "아는 사이" 입력 후보. 다음 판 후보는 결정적 Leiden 정제 · Ego-splitting 겹침 · 앞 시점 초기화 · 경계 사람 표시. GNN · 임베딩 · Infomap · 라벨 전파 · 클리크 퍼콜레이션 · 던바 층 · 부호 네트워크 · 버스트는 건너뛴다.

### Cited Findings
- 판정의 근거는 1~5절의 인용과 같다(Leiden 25%/16% — [PMC6435756](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6435756/); 라벨 전파 비결정 — [python-igraph](https://python.igraph.org/en/0.11.6/api/igraph.community.html); GED 포함도 — [arXiv:1207.4297](https://arxiv.org/pdf/1207.4297); CN/RA — [arXiv:0901.0553](https://arxiv.org/abs/0901.0553); 휴리스틱 ≈ GNN — [HAL](https://hal-bioemco.ccsd.cnrs.fr/NOS/hal-04643971v1)).

### Inferences
계산 비용은 5천 노드 · 약 5만 선 가정, 복잡도 기반 추정(실측 아님). "점수화 위험" 은 ADR-0004 기준.

| 기법 | 사용자 이득 | Swift 구현 비용 · 결정성 · 파이썬 거울 | 5천 노드 계산 | 프라이버시 · 점수화 위험 | 권고 |
|---|---|---|---|---|---|
| **방향 있는 포함도 매칭(GED식, 양 항만)** — Jaccard 대체/보완 | grew/merged/split 판정이 덜 헷갈림 | 수십 줄 · 결정적 · 거울 쉬움 | 무시 | 없음(질 항=중심성 가중은 빼야 함) | **지금** |
| **사건 보강: 그대로 · 다시 모임** | 동창 재회 같은 정서적 사건을 보여 줌 · "판정 불가" 와 "변화 없음" 구분 | 수십 줄(잠든 모임 보관) · 결정적 · 거울 쉬움 | 무시 | 없음(문구 중립) | **지금** |
| **짝짓기 문턱 재검토(0.3 → 0.1~0.2 실험)** | 가짜 "새로 생김 + 최근 기록 없음" 쌍 감소 | 상수 변경 + 정답표 견본 | 무시 | 없음 | **지금(실험 후 결정)** |
| **공동참여 무게 1/(n−1)** (고전 Newman 2001, 원문 미확인) | 큰 행사 하나가 모임을 지배하지 않음 | 몇 줄 · 결정적 · 거울 쉬움 | 무시 | 없음 | **지금(검토)** |
| **공통 이웃 기반 "아는 사이" 입력 후보** | 입력 병목 해소 — 가장 큰 실이득 | 수십 줄 + 화면 하나 + "아니요" 기억 저장 · 결정적 | 쌍 후보: 기록 단위로만 셈 → 작음 | 낮음(기기 내 · 근거=사실 · 점수 숨김 · 자동 생성 금지) | **지금** |
| 결정적 Leiden 정제 | 약하게 이어진 모임(최대 25%) 해소 · 끊김 보장 | +120~200줄 · θ→0 로 결정적 · 거울 가능 | 수십 ms | 없음 | **다음 판** |
| 앞 시점 분할로 Louvain 초기화(시간 절충) | 분기 사이 깜빡이는 가짜 사건 감소 | 수십 줄 · 결정적 | 무시 | 없음 | **다음 판** |
| Ego-splitting 겹침 모임 | "대학 친구이자 동료" 를 두 묶음에 | 알고리즘은 기존 재사용, 화면 · 배치 비용 큼 · 결정적 | Σ차수² — 큰 모임 클리크면 커짐 | 낮음 | **다음 판(화면 설계 후)** |
| 경계 사람 표시(간선 위 합의) | 어느 묶음인지 애매한 사람을 옅게 | 수십 줄 · 순서 3~5가지로 결정적 | 실행 3~5배 | 중(애매함 수치를 보이면 점수처럼 읽힘 — 숨김) | **나중** |
| 해상도 γ 3단 선택 | 크게/잘게 보기 | 이미 매개변수 있음 | 무시 | 없음 | **나중(기존 검토대로)** |
| 나 중심 구성 다양성(Blau, 분포 막대) | 내 인연이 어디서 왔는지 돌아보기 | 수십 줄 · 결정적 | 무시 | 낮음(나에 대한 지표 · 단일 숫자 금지) | **나중** |
| 분기 이탈 집계(새로 · 다시 · 쉬어 간 사람 수) | 사회적 서명 연구와 맞는 나 요약 | 시점 조각 재사용 · 결정적 | 무시 | 낮음(집계만) | **나중** |
| 다층 층 켜고 끄기 · 층별 탐지 비교 | 기록 vs 아는 사이 묶음 비교 | 기존 탐지 재사용 | 층 수 × 탐지 | 없음 | **나중** |
| Adamic–Adar · RA · Katz | CN 대비 정확도 소폭 | 거울 대상 증가 · Katz 는 행렬 | RA/AA 작음 · Katz 중 | 점수 노출 위험 | **건너뜀(RA 는 내부 동점 깨기만 가능)** |
| "소개해 보지 않은 X–Y" 중매 제안 | 의문 | 쉬움 | 작음 | **높음**(제3자 추론 · 사교 최적화 · 사람 가치 함의) | **건너뜀** |
| Infomap | 흐름 기반 — 무방향 공동참여엔 이득 불분명 | 큼 · 기본 구현 비결정(trials) | 중 | 없음 | **건너뜀** |
| 라벨 전파 | 빠름 | 작음 · 본래 비결정 · 결정화 시 품질 불안 | 작음 | 없음 | **건너뜀** |
| 클리크 퍼콜레이션 | 겹침 | 기록=클리크라 k-클리크 열거 폭발 | 큰 모임 있으면 매우 큼 | 없음 | **건너뜀** |
| 버스트 지수 · 베이지안 변화점 | 사람당 자료가 너무 적어 잡음 | 중~큼 | 작음~중 | 중(사람별이면 "활동 점수") | **건너뜀** |
| node2vec · GraphSAGE · GAT | 이득 없음(휴리스틱 대등) | 큼 · 난수/학습 · 거울 불가 | 중~큼 · Core ML 연산 지원 불확실 | 높음(사람 유사도 점수) | **건너뜀** |
| 그래프 파운데이션 모델 · LLM+그래프 | 모임 이름 정도 | 매우 큼 · 비결정 | 큼(메모리) | 중 | **건너뜀** |
| 던바 층 분류 | 등급 나누기 | 쉬움 | 무시 | **높음**(사람 순위) | **건너뜀** |
| 부호 네트워크 | 없음 | 중 | 작음 | **높음**(실존 인물 부정 기록) | **건너뜀** |

### Gaps
- 모든 계산 비용은 복잡도 기반 추정이다. 아이폰 실측은 CI macOS 러너나 실기기에서 재야 한다.
- 문턱 0.1 대 0.3 의 우리 자료상 효과는 정답표 견본 실험 전에는 알 수 없다.
- 이번 세션은 원문 PDF 에 접근하지 못해 수치 일부(Greene 0.1, Lü & Zhou 2010 RA 최상, resurgence 사건명)는 2차 출처에 기댄다.
