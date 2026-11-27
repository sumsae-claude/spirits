# 인수인계 (HANDOFF) — 정령계약자

> 새 Claude 세션이 이 프로젝트를 이어받기 위한 문서입니다. **작업 시작 전에 이 문서와 `docs/DESIGN.md`를 먼저 읽으세요.**
> 마지막 갱신: 전투 연출(공격/소환/퇴장 애니메이션)·반격·배속·거점 초상화 작업 직후.

## 0. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 게임 | 「정령계약자」(가제) — 세로 화면 헥스 턴제 SRPG. 정령사가 폭주 정령을 **디스펠**해 계약하고 **소환**해 싸움 |
| 영감 | 90년대 슈와시스템 *Spiritual Soul*의 구조(디스펠 계약·장비·진화). **이름·캐릭터·스토리·아트는 전부 오리지널** — 원작을 복제하지 말 것 |
| 엔진 | Godot 4.3+ / GDScript / GL Compatibility, 720×1280 세로 |
| 저장소 | `sumsae-claude/spirits` (브랜치 `main`) |
| 판매 형태 | 패키지형: 챕터 1~2 무료 → 정식판 1회 구매, 라이트 광고/과금, 유료 가챠 없음 |
| 사용자 | 한국어로 소통. 기획 방향은 사용자와 상의, 세부 구현은 위임받음 |

## 1. ⚠️ 중요한 제약

- **이 저장소의 코드는 아직 Godot에서 한 번도 실행된 적이 없습니다.** 클라우드 환경에서 Godot 바이너리 실행이 권한 정책으로 막혀 있어서 모든 코드를 "읽고 검토"만 했습니다. 사용자가 PC에서 실행해 보고 에러를 알려주기로 함 → **에러 리포트가 오면 최우선으로 수정.**
- GDScript 작성 시 주의: `:=`로 Variant 값을 추론하지 말 것(타입 명시), `min/max` 대신 `mini/maxf` 등 사용.
- 데이터 파일(JSON)을 바꾼 뒤에는 Python으로 JSON 유효성과 참조(스킬 id, 보상 아이템, 대화 키)를 검사하는 습관 유지.
- 커밋 메시지는 한국어, push는 `git push origin main`.

## 2. 현재까지 구현된 것 (v0.8+)

### 전투 (`scripts/battle/battle.gd` — 가장 큰 파일)
- 8×10 헥스, 지형(숲·물가·언덕·용암·마법진·바위) 효과, 스토리 스테이지는 시드 고정 맵
- 라운드 = **아군 턴(유닛 자유 순서) → 적 턴(속도순)**, 이동 1 + 행동 1, 이동 미리보기(파란 칸 2번 탭)·이동 취소
- **정령사**가 직접 출전(쓰러지면 패배): 소환(연속 소환, 한도 3+4레벨마다+1, 최대 6)/귀환/디스펠(사거리 2)/정령사 스킬/공격
- 상성 **바람 ▶ 불 ▶ 풀 ▶ 물 ▶ 바람** (×1.5/×0.75), 적 칸 색으로 유리(초록)/보통(노랑)/불리(회색) 표시
- 적 정령사 AI(거리 유지·상성 소환·회복/공격 스킬), 적 정령사의 정령도 디스펠 가능(×0.6)
- 수호 정령 보스: HP 1 아래로 안 떨어짐, 30% 이하에서 "실이 드러나" 디스펠 가능(+30%)
- 버프/디버프, 대상 탭 → 행동 메뉴(예상 피해·성공률·반격 표시), 사용 불가 버튼 흐리게
- **(최신) 연출**: 근접 돌진+베기, 스킬 기모으기+속성별 투사체(불=불덩이/물=물줄기/풀=잎/바람=초승달)+폭발, 디스펠 금빛 실, 피격 붉은 번쩍+흔들림, 소환 마법진+빛기둥+통 등장, 쓰러짐 빛 입자로 흩어짐, 계약/귀환 금빛 고리로 사라짐, 회복/버프/디버프 이펙트 (`_draw_fx`, `_anim_*`, `_vanish`)
- **(최신) 반격**: 일반 공격(근접)을 받고 살아남으면 60% 위력 반격(`BattleLogic.COUNTER_RATIO`), 스킬엔 반격 없음, AI도 반격 피해 고려
- **(최신) 배속**: 아군 턴 버튼 "속도 ×1/×2" (`Engine.time_scale`, `GameState.flags.battle_speed`)
- 도트 스프라이트(정령 20 + 정령사 4) 표시, 대기 모션, 행동 끝난 유닛 어둡게

### 스토리 / 진행
- `data/chapter1.json`: 1장 「끊어진 실」 6 스테이지 + 대화 전부(시작 속성에 따라 고향/적/수호 정령 변경)
- 월드맵(`scripts/ui/world_map.gd`), 대화창(`scripts/ui/dialogue_box.gd`), 진행 저장(`GameState.cleared_stages/flags`)
- 거점(`scripts/ui/hub.gd`): 정령사·계약 정령(최대 6)·보관함, 선봉 지정, 장비(정령사 포함), 사냥터/연습 대결, **(최신) 상세 화면 상단 초상화**(2D 일러스트 있으면 일러스트, 없으면 도트 확대)

### 아트
- 혼합형 확정: **전투=도트(32×32)**, 도감/대화/초상화=2D SD 일러스트
- 도트 생성기 `tools/art/sprites.py` → `assets/sprites/` (목록 `art/sprites_sheet.png`)
- 2D SD 초상화 **전체 완료**: 정령 20종 + 정령사 4종 → `assets/portraits/<종족id>.png`, `summoner_<속성>.png` (목록 `art/portraits_sheet.png`)
  - 대표 4종 원본: `art/concepts/` (`tools/art/sd.py`), 나머지: `art/portraits_src/*.svg` (`tools/art/sd_all.py` → `tools/art/render_portraits.js`로 PNG 렌더)

## 3. 다음 할 일 (우선순위 순)

1. **사용자 실행 테스트 대응** — 에러/밸런스 피드백 수정 (특히 최신 연출·반격 코드)
2. 2D 초상화를 **대화창(화자 얼굴)·월드맵 스테이지 정보**에도 활용 (지금은 거점 상세 화면에서만 표시)
3. 사용자에게 제안해 둔 선택 사항 (사용자 승인 후 진행)
   - 전투 시작 전 **배치 단계** (정령사·선봉 위치 선택)
   - 보스전/필살기 한정 **전투 컷인** 연출 (설정에서 끄기)
4. **성장 시스템** (기획서 2단계): 정령 도감·색이 다른 정령, 계승, 정령의 제단(정령석, 무료 재화 가챠), 상점, 장비 강화
5. 챕터 2~5, 무한의 탑, 엔딩 분기, 광고/결제 연동 → 비공개 테스트 → 출시

## 4. 파일 지도

```
data/            spirits · skills · summoner · summoner_skills · equipment · terrain · chapter1 (JSON)
scenes/          main_menu · hub · world_map · battle (.tscn, UI는 스크립트에서 생성)
scripts/autoload game_data.gd (데이터·상성·테마·스프라이트/초상화 로드), game_state.gd (진행·저장·스테이지)
scripts/core     spirit.gd (능력치·경험치·진화), summoner.gd (정령사: 소환/스킬/장비)
scripts/battle   battle.gd (전투 씬 전체), battle_logic.gd (공식), battle_unit.gd (유닛 상태·버프·연출값), hex_grid.gd
scripts/ui       ui_kit.gd, main_menu.gd, hub.gd, world_map.gd, dialogue_box.gd
assets/          sprites/ (도트), portraits/ (2D 일러스트)
art/ tools/art/  시안·시트 이미지와 생성 스크립트
docs/            DESIGN.md (기획서), HANDOFF.md (이 문서)
```

## 5. 새 세션 시작 방법

Claude Code에서 이 저장소(`sumsae-claude/spirits`)를 연결한 새 세션을 열고 아래처럼 요청하세요.

```
docs/HANDOFF.md와 docs/DESIGN.md를 읽고 정령계약자 프로젝트를 이어서 진행해줘.
```
