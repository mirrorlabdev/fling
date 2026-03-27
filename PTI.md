# PTI — Post-Terminal Interface

> "터미널을 대체하는 게 아니라, 터미널을 UI 시스템으로 승격시킨다"

## 배경

Fling을 만들면서 확인한 것:
- 터미널의 입력 문제는 **외부 레이어(Fling)로 해결 가능**
- 하지만 출력/렌더링 문제는 여전히 터미널에 갇혀 있음
- 터미널은 "상태를 표현하는 시스템"이 아니라 "화면을 그리는 시스템"

## 핵심 아이디어

입력 / 상태 / 출력 / 렌더링을 분리한다.

```
[ Human ]
    ↓
[ Input Layer ]       ← Fling (완료)
    ↓
[ Runtime / CLI ]     ← 기존 CLI 그대로
    ↓
[ Output Adapter ]    ← stdout 파싱 → 구조화 (핵심 난관)
    ↓
[ UI Renderer ]       ← WPF 기반, 터미널이 아닌 구조화된 UI
```

## 기존 vs PTI

```
기존:  CLI → ANSI → Terminal → Render (전부 섞임)
PTI:   CLI → text stream → Adapter → structured state → UI Renderer
```

## Output Adapter (핵심이자 가장 어려운 부분)

역할: stdout/stderr intercept → ANSI 제거/해석 → 상태 추출

```json
{ "type": "text", "content": "Installing..." }
{ "type": "progress", "value": 45 }
{ "type": "status", "message": "Running tests" }
```

### 왜 어려운가

- CLI마다 출력 형식이 전부 다름
- ANSI escape 해석은 수십 개 터미널이 각자 다르게 처리
- "의미 추출"은 사실상 각 CLI별 파서 필요
- 대상 CLI가 출력 형식 바꾸면 파서 깨짐

### 현실적 접근

범용은 함정. **LLM CLI 특화**로 시작.
- Claude Code, Codex 등 출력 패턴 파싱
- thinking / tool / response 분리
- JSON 지원 CLI → 구조화, 일반 CLI → 텍스트 fallback

## 로드맵

| Phase | 내용 | 상태 | 난이도 |
|-------|------|------|--------|
| **1 — Input** | Fling (독립 입력 레이어) | **완료** | - |
| **2 — Output** | LLM CLI 전용 stdout 파서 | 미착수 | 중 |
| **3 — Renderer** | WPF UI (Fling 기반 확장) | 미착수 | 중 |
| **4 — Protocol** | CLI 공통 structured output 프로토콜 | 먼 미래 | 극상 |

## 타이밍 판단

- Anthropic/OpenAI가 structured output 프로토콜 공개하면 → Phase 2 즉시 착수
- 그 전까지는 Fling을 키우면서 Input Layer 완성도 높이기
- 오픈소스 기여: 터미널/CLI 쪽 IME 관련 이슈에 Fling 경험 기반으로 참여

## 철학

1. **터미널을 없애지 않는다** — 기존 CLI 그대로 사용
2. **렌더링을 분리한다** — UI는 UI답게
3. **상태를 복원한다** — 텍스트 → 의미
4. **점진적 대체** — fallback 항상 존재

## 왜 지금 가능한가

- LLM CLI 등장으로 텍스트 스트림이 "의미"를 가지게 됨
- 과거: "텍스트 출력"이면 충분
- 지금: "구조 + 의미" 필요
- 사용자 UX 기대치 상승 (Cursor, Windsurf 등 IDE 통합 트렌드)

## 한 줄 정의

> **이건 새로운 터미널이 아니라 "터미널 이후의 인터페이스"다**

---

*Fling에서 시작. 빡침에서 시작. 2026-03-27.*
