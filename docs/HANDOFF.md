# 인수인계 (HANDOFF) — 정령계약자

> 새 Claude 세션이 이 프로젝트를 이어받기 위한 문서입니다. **작업 시작 전에 이 문서와 `docs/DESIGN.md`를 먼저 읽으세요.**
> 마지막 갱신: 행동마다 경험치, 골드 표시 디자인, 하린 초상화, 명령 메뉴 자리 선정, 언덕→모래밭 직후.

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

- **Godot 실행 가능** (사용자가 허락함): 클라우드에서 공식 바이너리를 받아 헤드리스로 실행한다. 받는 법:
  `curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && unzip g.zip` (스크래치 폴더에)
  - 임포트·컴파일 확인: `godot --headless --path . --import`
  - **자동 플레이 테스트**: `godot --headless --path . res://tests/smoke_test.tscn` (새 게임 → 1-1 튜토리얼 → 1장 → 대륙 지도 → 2장, 20분 넘게 걸리니 백그라운드로). `SCRIPT ERROR` 줄이 버그, `SMOKE FAIL`이 진행 실패
  - 한 스테이지 승률: `SMOKE_STAGE=1-6 SMOKE_TRIES=4 godot --headless --path . res://tests/smoke_test.tscn`
  - 주의: 테스트 봇은 단순해서(정령사는 소극적, 정령은 적 AI를 빌려 씀) 보스 밸런스는 사람 플레이로 확인할 것
- 화면(손맛·레이아웃)은 헤드리스로 못 본다 → 사용자 실행 피드백 우선.
- GDScript 작성 시 주의: `:=`로 Variant 값을 추론하지 말 것(타입 명시), `min/max` 대신 `mini/maxf` 등 사용.
- 데이터 파일(JSON)을 바꾼 뒤에는 Python으로 JSON 유효성과 참조를 검사하고, 가능하면 자동 플레이 테스트도 돌릴 것.
- 커밋 메시지는 한국어. 클라우드 세션이 정한 작업 브랜치에 push → 사용자가 원하면 main에 병합(이번 세션은 사용자 요청으로 매번 main 병합).

## 2. 현재까지 구현된 것 (v0.8+)

### 전투 (`scripts/battle/battle.gd` — 가장 큰 파일)
- **8×12 헥스**(칸 46px, v0.9에서 8×10→확대), 지형(숲·물가·언덕·용암·마법진·바위) 효과, 스토리 스테이지는 시드 고정 맵
- 라운드 = **아군 턴(유닛 자유 순서) → 적 턴(속도순)**, 이동 1 + 행동 1, 이동 미리보기(파란 칸 2번 탭)·이동 취소
- **정령사**가 직접 출전(쓰러지면 패배): 소환(연속 소환, 한도 3+4레벨마다+1, 최대 6)/귀환/디스펠(사거리 2)/정령사 스킬/공격
- 상성 **바람 ▶ 불 ▶ 풀 ▶ 물 ▶ 바람** (×1.5/×0.75), 적 칸 색으로 유리(초록)/보통(노랑)/불리(회색) 표시
- 적 정령사 AI(거리 유지·상성 소환·회복/공격 스킬), 적 정령사의 정령도 디스펠 가능(×0.6)
- 수호 정령 보스: HP 1 아래로 안 떨어짐, 30% 이하에서 "실이 드러나" 디스펠 가능(+30%)
- 버프/디버프, 대상 탭 → 행동 메뉴(예상 피해·성공률·반격 표시), 사용 불가 버튼 흐리게
- **(최신) 연출**: 근접 돌진+베기, 스킬 기모으기+속성별 투사체(불=불덩이/물=물줄기/풀=잎/바람=초승달)+폭발, 디스펠 금빛 실, 피격 붉은 번쩍+흔들림, 소환 마법진+빛기둥+통 등장, 쓰러짐 빛 입자로 흩어짐, 계약/귀환 금빛 고리로 사라짐, 회복/버프/디버프 이펙트 (`_draw_fx`, `_anim_*`, `_vanish`)
- **반격**: **공격 탭**의 공격(기본 공격·정령 스킬·정령사 공격 스킬)을 받고 살아남은 쪽은, 공격자가 바로 옆(거리 1)이면 기본 공격 60% 위력으로 반격(`BattleLogic.COUNTER_RATIO`). 떨어져서 원거리 스킬로 치면 반격 없음. 정령사 스킬(회복·버프·디버프)·디스펠은 반격 없음. AI도 반격 피해 고려
- **(최신) 공격 탭** (사용자 확정 규칙): 정령 = 기본 공격 + 스킬 최대 2개 (정령에게 '스킬' 메뉴는 없음). 정령사 = 기본 공격 + 속성 공격 스킬 + 디스펠, 나머지 정령사 스킬은 '스킬' 메뉴. 진화 전 정령은 거의 기본 공격만(빨리 진화하는 계열은 0개, 늦게 진화하는 계열은 Lv6에 약한 스킬 1개), 진화형은 스킬1 바로 + 스킬2 Lv12/15
- **(최신) 히든 스킬 + 수동 진화**: 진화는 자동이 아니라 거점 상세 화면의 '진화시키기' 버튼. 진화 레벨 + 5(`Spirit.HIDDEN_SKILL_GAP`)까지 진화하지 않으면 종족별 숨은 기술(`spirits.json` `hidden_skill`, `skills.json` `"hidden": true`)
- **(최신) 명령 메뉴**: 원작처럼 유닛 옆에 세로 메뉴(공격 ▸ / 스킬 ▸ / 소환 ▸ / 귀환 / 대기 / 이동 취소). 적을 누르면 그 적 옆에 행동 목록. 아래 패널은 유닛 정보·안내·행동 설명만. '턴 종료'는 위쪽 HUD, 후퇴·도움말은 '≡' 메뉴
- **(최신) 배속**: 오른쪽 위 HUD 버튼 ▶×1 / ▶▶×2 / ▶▶▶×3 순환 (`Engine.time_scale`, `GameState.flags.battle_speed`)
- **(최신) 전투 화면 개편**: 지역별 도트 배경 `assets/battle/bg_<속성>.png` + 지형 헥스 타일 `tile_<지형>.png` (`tools/art/battle_bg.py`로 생성). 평지는 배경이 비치고, 이동/대상 표시는 반투명 덧칠(`_cell_overlay`). 위쪽 HUD(라운드 알약·`?` 도움말·배속), 아래 명령 패널은 맵 바로 아래부터 화면 끝까지(긴 화면은 패널이 커짐). 상성·지형 범례는 `?` 도움말로 이동. 배치 참고 이미지: `art/battle_layout_mock.png`
- **(최신) 1-1 고정 튜토리얼 스테이지**: `stages[0]`에 `terrain`(고정 지형), 적 `cell`(고정 위치), `script`(단계 목록). 처음 깰 때만 스크립트 진행 — 정령 선택 → 지정 칸 이동 → 유리한 적 기본 공격 → 정령사 선택 → 지정 칸 이동 → 디스펠(반드시 성공, 대상은 HP 1 밑으로 안 떨어짐) → 적 턴 대기 → 방금 계약한 정령 소환 → 자유 전투. 진행 중엔 지시한 칸/대상/메뉴 버튼만 동작(`_script_tap`, `_script_allows`, `_add_action`의 kind). 엔진: battle.gd "고정 튜토리얼 스크립트" 구역
- **(최신) 전투 중 계약한 정령은 다음 차례부터 바로 소환 가능**, HP는 깎인 그대로 (원작 고증)
- **(최신) 소환 = 계약 정령 전체**(파티 + 보관함 + 방금 계약): 소환을 고르면 아래 패널이 소환 목록(속성 탭, 지금 적에게 유리한 정령 → 레벨 순, 못 쓰는 정령은 흐리게 아래로). 동시 소환 수 제한(3~6)은 그대로
- **(최신) 귀환**: 정령사 메뉴엔 없음. 정령이 정령사 바로 옆 칸이나 마법진 위일 때만 '귀환' (`_can_recall`)
- **(최신) 마법진 진영 색**: 우리 편 파랑 / 적 정령사·그 정령 빨강 / 야생 정령은 원래 보라. 비면 마지막 색 유지. 바뀔 때 색 번짐·별 회전·고리 맥박·빛 입자 (`_update_circles`, `_draw_circle_mark`)
- **(최신) HUD**: `[턴 종료] [후퇴(확인 창)] [?] [▶배속]`. 명령 메뉴 버튼은 글자 폭에 맞춰 좁게(최소 132px)
- 상성 튜토리얼용 적 배치: 1-1 = 고향 속성이 이기는 정령(`@prey_a`, 초록) + 같은 속성(노랑), 1-2 = 고향 속성에 강한 정령(`@strong_a`, 회색) 포함. 튜토리얼 focus `advantage`/`disadvantage`가 그 적을 가리킴
- **(최신) 전투 중 튜토리얼**: `chapter1.json`의 `tutorials` (스테이지별 + `"*"` 공통). 이벤트(start/select/moved/choose/weak/captured/counter/enemy_phase/round2/revealed)에 맞춰 화자 초상화 말풍선 + 가리키는 칸 금테·화살표. 한 번 본 단계는 `flags.tut_<id>`. 예전 대화 속 "▶ 조작 설명" 줄은 삭제
- 호흡: 적 행동 간격 0.25초, 야생 정령은 2행에서 출발. (피해 1.3배는 사용자 요청으로 되돌림 — 능력치가 오르면 자연히 빨라진다는 판단)
- 도트 스프라이트(정령 20 + 정령사 4) 표시, 대기 모션, 행동 끝난 유닛 어둡게

### 경험치 (최신, 사용자 확정 규칙)
- 전투가 끝날 때 나눠 주지 않고 **행동할 때마다 바로**: 공격(기본·스킬·반격·정령사 공격)으로 입힌 피해 비율 × `xp_reward × 0.5`, **마무리(쓰러뜨림)** 하면 `xp_reward` 추가, 디스펠 성공도 `xp_reward`, 회복·버프·디버프 스킬 3 (`BattleLogic.HIT_XP_RATIO` 등). 소환 안 한 정령은 경험치 없음
- 레벨업은 전투 중 그 자리에서 (LEVEL UP 연출), 결과 화면에 정령별 획득 경험치 요약 (`_award_xp`, `_xp_summary`)

### 골드 표시 · 기타 (최신)
- `UIKit.gold_badge(양, 크기, 앞글자, 설명)`: 도트 동전(`assets/ui/coin.png`, `tools/art/ui_icons.py`) + 금색 숫자 알약. 보상 줄 `"@gold:<양>:<설명>"`은 `UIKit.reward_line()`이 알약으로 그림 (전투 결과·이벤트 결과·스테이지 보상). 지도 오른쪽 위·거점·상점에 사용
- 하린 초상화 `npc_harin_<속성>` 4종 (지역 속성 따라감, 표식 `@harin_reg`, 스테이지 summoner `portrait` 필드)
- 명령 메뉴 자리: 오른쪽/왼쪽 × 가운데/위/아래 중 이동 칸·대상·튜토리얼 표시를 가장 적게 가리는 곳 (`_place_cmd_menu`). 1-1 고르기·이동·대기 단계에서는 메뉴 숨김
- 지형 `hill`은 이름·그림을 **모래밭**으로 변경 (효과는 그대로: 이동 2·바람 1, 바람 +20%, 원거리 +1)

### 대륙 지도 · 2장
- `data/chapter2.json`: 2장 「안개 너머의 길」 — 지점 그래프 `nodes` (type: battle/boss/event/shop/town, `pos`, `links`, `goal`). 지역 = 다음 지역(라이벌 속성, `"region": "next"`)
- 지역 표식: `@reg_a/@reg_b/@reg_guardian/@reg` = 지금 챕터 지역 속성 기준 (`GameState.active_chapter`, `chapter_element()`), 대화 치환 `{region}` `{reg_guardian}`
- 1장 `stages`는 `GameData._setup_chapters()`에서 일직선 지점으로 자동 변환. 지점 열림 = 이어진 지점을 지나왔는가 (`node_unlocked`), 챕터 열림 = 이전 챕터 `goal` 지점 클리어
- `world_map.gd` 전면 개편: 대륙 지도(4지역 + 무색의 도시) / 지역 지도(지점·길·정령사 말 이동), 상점(재고는 승리 3회마다 바뀜, 반값 판매)·마을(회복·저장·거점)·이벤트(선택지 효과: gold/item/heal/spirit/battle) 창
- **골드** `GameState.gold` (새 게임 50, 승리 = 10 + 정령 레벨 합×3, 스테이지 보상 `rewards.gold`). 장비 가격 `equipment.json` `price` 또는 능력치로 계산(`GameData.equipment_price`)
- 대화·튜토리얼·화자 초상화는 모든 챕터에서 찾음 (`GameData.dialogue`, `tutorials_for`, `speaker_portrait_table`)

### 스토리 / 진행
- `data/chapter1.json`: 1장 「끊어진 실」 6 스테이지 + 대화 전부(시작 속성에 따라 고향/적/수호 정령 변경)
- 월드맵(`scripts/ui/world_map.gd`), 대화창(`scripts/ui/dialogue_box.gd`), 진행 저장
- **(최신) 대화창 화자 초상화**: 주인공은 왼쪽, 다른 인물은 오른쪽(좌우 반전)에 미끄러지며 등장. 화자 → 초상화는 `GameState.speaker_portrait_key()` (`{player}`/`{rival}`/`{guardian}`은 코드에서, NPC는 `chapter1.json`의 `speaker_portraits`)
- **(최신) 월드맵 적 초상화**: 스테이지 정보 패널에 등장 적 카드(보스·정령사 금테, 무작위 정령 "?") — `GameState.stage_preview()`(`GameState.cleared_stages/flags`)
- 거점(`scripts/ui/hub.gd`): 정령사·계약 정령(최대 6)·보관함, 선봉 지정, 장비(정령사 포함), 사냥터/연습 대결, **(최신) 상세 화면 상단 초상화**(2D 일러스트 있으면 일러스트, 없으면 도트 확대)

### 아트
- 혼합형 확정: **전투=도트(32×32)**, 도감/대화/초상화=2D SD 일러스트
- 도트 생성기 `tools/art/sprites.py` → `assets/sprites/` (목록 `art/sprites_sheet.png`)
- 2D SD 초상화 **전체 완료**: 정령 20종 + 정령사 4종 + NPC 2종(촌장 `npc_elder`, 결사 정찰병 그레이 `npc_grey`) → `assets/portraits/<종족id>.png`, `summoner_<속성>.png` (목록 `art/portraits_sheet.png`)
  - 대표 4종 원본: `art/concepts/` (`tools/art/sd.py`), 나머지: `art/portraits_src/*.svg` (`tools/art/sd_all.py` → `tools/art/render_portraits.js`로 PNG 렌더)

## 3. 다음 할 일 (우선순위 순)

1. **사용자 실행 테스트 대응** — 에러/밸런스 피드백 수정 (특히 새 전투 HUD·튜토리얼 말풍선 위치, 연출·반격 코드)
   - 호흡 추가 단축 후보(사용자와 상의): 자동 전투 버튼, 적 턴 건너뛰기, 스테이지당 적 수 조정
   - 명령 메뉴 버튼 글이 길면(대상 메뉴의 예상 피해 줄) 메뉴가 넓어짐 → 실행해 보고 조정
2. 사용자에게 제안해 둔 선택 사항 (사용자 승인 후 진행)
   - 전투 시작 전 **배치 단계** (정령사·선봉 위치 선택)
   - 보스전/필살기 한정 **전투 컷인** 연출 (설정에서 끄기)
3. **성장 시스템** (기획서 2단계): 정령 도감·색이 다른 정령, 계승, 정령의 제단(정령석, 무료 재화 가챠), 상점, 장비 강화
4. 보관함 화면 정리(사용자 요청, 다음 단계) · 3~5장 내용(대륙 지도 틀은 완성)
5. 무한의 탑, 엔딩 분기, 광고/결제 연동 → 비공개 테스트 → 출시

## 4. 파일 지도

```
data/            spirits · skills · summoner · summoner_skills · equipment · terrain · chapter1 (JSON)
scenes/          main_menu · hub · world_map · battle (.tscn, UI는 스크립트에서 생성)
scripts/autoload game_data.gd (데이터·상성·테마·스프라이트/초상화 로드), game_state.gd (진행·저장·스테이지)
scripts/core     spirit.gd (능력치·경험치·진화), summoner.gd (정령사: 소환/스킬/장비)
scripts/battle   battle.gd (전투 씬 전체), battle_logic.gd (공식), battle_unit.gd (유닛 상태·버프·연출값), hex_grid.gd
scripts/ui       ui_kit.gd, main_menu.gd, hub.gd, world_map.gd, dialogue_box.gd
assets/          sprites/ (도트), portraits/ (2D 일러스트), battle/ (전투 배경·지형 타일)
art/ tools/art/  시안·시트 이미지와 생성 스크립트
docs/            DESIGN.md (기획서), HANDOFF.md (이 문서)
```

## 5. 새 세션 시작 방법

Claude Code에서 이 저장소(`sumsae-claude/spirits`)를 연결한 새 세션을 열고 아래처럼 요청하세요.

```
docs/HANDOFF.md와 docs/DESIGN.md를 읽고 정령계약자 프로젝트를 이어서 진행해줘.
```
