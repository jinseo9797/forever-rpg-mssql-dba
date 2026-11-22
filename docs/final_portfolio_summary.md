# 최종 통합 정리 — Forever RPG SQL Server DBA 포트폴리오

## 1. 프로젝트 개요

Forever RPG는 RPG 게임에서 발생하는 캐릭터·상점·아이템·사냥 데이터를 Microsoft SQL Server로 관리하는 개인 실습 프로젝트입니다. SQL Server의 데이터 모델링, 트랜잭션, 인덱스, 백업·복원, 잠금·교착 상태를 실습하고, FastAPI·웹 게임을 연결해 실제 데이터 처리 흐름을 확인했습니다.

**중점:** 데이터베이스 테이블의 구조와 관계는 직접 설계했고, 저장 프로시저 작성에는 AI의 도움을 받았습니다. FastAPI·JavaScript 웹 게임 구현에도 AI를 활용했으며, SQL Server 실행·성능 측정·장애 재현·데이터 검증은 직접 수행했습니다.

## 2. 아키텍처 및 책임

```text
브라우저 (HTML/CSS/JavaScript)
  ├─ fetch("GET /characters/{id}", "/items", "/monsters", ...)
  └─ fetch("POST /purchase", "/battle/start", "/battle/attack")
               │ HTTP JSON 요청
               ▼
FastAPI (Python + pyodbc)
  ├─ 요청값 확인
  ├─ 저장 프로시저 호출
  └─ 실행 결과를 JSON으로 반환
               │ SQL Server 연결
               ▼
Microsoft SQL Server — ForeverRPG
  ├─ V001 / V002 / V003 스키마
  ├─ usp_PurchaseItem: 골드 차감 + 인벤토리 지급 + 구매 이력
  ├─ usp_StartBattle / usp_AttackBattle: 전투 상태 및 턴 처리
  ├─ usp_HuntMonster: 승리 검증 + 보상 지급 + 사냥 이력
  └─ 트랜잭션 성공: COMMIT / 실패: ROLLBACK
               │
               ▼
FastAPI 응답 → JavaScript가 캐릭터·인벤토리·전투/사냥 기록 재조회
```

SSMS는 SQL Server를 관리하고 실습하는 도구이며 웹 요청의 직접적인 통신 경로에는 포함되지 않습니다.

## 3. 구현 범위

| 구분 | 구현 내용 |
|---|---|
| 데이터 모델 | V001: Characters, Items, Monsters, Inventory, PurchaseHistory, HuntHistory, SchemaVersions (7개) |
| 스키마 패치 | V002: Characters.LastLoginAt / V003: BattleEncounters (현재 8개 테이블) |
| 조회 | 캐릭터, 상점 아이템, 인벤토리, 활성 몬스터, 최근 사냥 기록, 진행 중인 전투 |
| 구매 | `usp_PurchaseItem`에서 골드·인벤토리·구매 이력 원자적 처리 |
| 전투 | `usp_StartBattle`, `usp_AttackBattle`로 서버 측 HP/승패 상태 관리 |
| 보상 | `usp_HuntMonster`에서 승리·미지급 상태를 확인해 지급 |
| 운영 실습 | 인덱스 튜닝, FULL 백업·복원, Blocking·Deadlock 분석 |

## 4. 실측 및 검증 결과

### 스키마 및 제약조건

V001에서 7개 테이블과 6개 외래키, 11개 CHECK, 3개 UNIQUE 제약조건을 대상으로 검증했습니다. V003 패치 후 `BattleEncounters` 테이블이 추가되었습니다.

관련 문서: [01단계](day01_database_design.md)

### 구매 트랜잭션

정상 구매 시 골드 차감, 인벤토리 갱신, `PurchaseHistory` 기록을 확인했습니다. 오류 발생 시 데이터 변경이 되돌려지는지 확인했고, FastAPI `POST /purchase` 실행 결과 `200 OK` 및 실제 구매 금액 500 Gold를 확인했습니다. 이후 로컬 DB에서도 변경을 확인했습니다.

관련 문서: [02단계](day02_transaction_test.md)

### 인덱스 성능

최근 사냥 기록 TOP 20 조회에서 강제 스캔 및 복합 인덱스 사용을 5회 비교했습니다.

| 측정 | 강제 스캔 | 복합 인덱스 |
|---|---:|---:|
| 평균 논리적 읽기 | 449 | 3 |
| 감소율 | | 약 99.33% |

힌트 없는 실제 실행 계획에서 Index Seek가 선택되는 것도 확인했습니다. 이 비교는 로컬 실습의 특정 쿼리·데이터 조건이며 실제 서비스 전체 성능 개선율을 의미하지 않습니다.

관련 문서: [03단계](day03_index_optimization.md)

### 패치·백업·복원

V002 재실행 시 패치 이력이 중복 등록되지 않는 것을 확인했습니다. SQL Server 전체 백업과 별도 `ForeverRPG_RestoreTest` 데이터베이스 복원을 진행하고, 스키마·주요 객체 및 테이블별 행 수를 비교했습니다.

관련 문서: [04단계](day04_patch_backup_restore.md)

### 장애 대응

| 검증 | 실측 결과 |
|---|---|
| Blocking | 세션 92가 세션 78을 대기, `LCK_M_X`, 대기 9,724ms |
| 해소 확인 | 롤백 후 세션 트랜잭션 0, 조회 시점의 차단 요청 0건 |
| Deadlock | 오류 1205, 세션 75 희생자 |
| 원인 분석 | Deadlock XML에서 두 세션이 서로의 KEY 잠금을 기다리는 순환 관계 확인 |

관련 문서: [Blocking](day05_blocking_troubleshooting.md) · [Deadlock](day05_deadlock_analysis.md)

### 웹 게임 및 턴제 전투

브라우저에서 FastAPI·SQL Server 연결과 구매·사냥 기능이 실제 작동함을 확인했습니다. V003의 첫 승리 기록은 다음과 같습니다.

| BattleId | CharacterId | MonsterId | TurnCount | MonsterHP | Status | RewardClaimed |
|---:|---:|---:|---:|---:|---|---:|
| 1 | 1 | 2 | 10 | 0 | Won | 1 |

종료된 전투에 다시 공격 요청을 보내고 골드와 사냥 기록 수가 유지되는 것을 확인했습니다. 이는 **순차적인 재요청 차단 검증**이며 동시 요청에 관한 보장은 아닙니다.

관련 문서: [09단계](day09_battle_validation.md)

## 5. AI 활용 및 직접 수행 범위

| 영역 | AI를 활용한 작업 | 직접 수행한 작업 |
|---|---|---|
| DB 테이블 설계 | 테이블 설계 자체는 직접 수행; SQL 문법·문서 정리 지원 | **테이블 구조, 테이블 간 관계, PK·FK·제약조건 설계** 및 SSMS 스키마 검증 |
| 저장 프로시저 | **AI의 도움을 받아 조회·구매·전투·보상 프로시저 작성** | SSMS 등록·실행, 트랜잭션·오류 처리 및 정합성 검증 |
| 성능·운영 | 인덱스 비교, 패치·복원 검증 SQL 및 보고서 정리 | 인덱스 적용·실측·실행 계획 확인·백업·복원 |
| 장애 분석 | Blocking/Deadlock 재현 절차 및 XML 해석 지원 | 다중 세션 재현, DMV/오류/XML 확인 및 롤백 |
| API·웹 UI | FastAPI·pyodbc·JavaScript `fetch()` 통신과 웹 화면 코드 구현 | 로컬 서버 실행, DB 연결, 구매·전투 동작 확인 |
| 전투 기능 | 전투·보상 프로시저 및 V003 SQL 구현 보조 | **전투 상태 테이블 설계**, 실제 승리 및 종료 전투 재공격 후 DB 결과 검증 |

DB 테이블 설계는 직접 수행한 작업으로 명시하고, 저장 프로시저와 웹 게임 구현은 AI의 도움을 받은 영역으로 구분했습니다. 측정·실행·검증 결과는 로컬 실습에 근거해 작성했습니다.

## 6. 검증되지 않은 부분

- 구매·전투에 대한 대규모 동시 요청, 성능 부하, 다중 API 인스턴스 검증
- 동시 재공격 상황에서의 보상 중복 방지에 대한 독립적인 스트레스 테스트
- 실제 로그인·인증·권한 분리 및 외부 공개용 보안
- 장애 발생 시 자동 재시도·멱등성 및 운영 모니터링
- 백업·복원 이후 모든 행 값의 완전한 일치, 복구 목표 시간
- 현재 사냥 기록은 `HuntHistory`에 `BattleId`가 없어 개별 전투와 지급 이력을 직접 조인할 수 없음

## 7. 취업 제출 시 설명 요약

> RPG 게임의 데이터베이스 테이블과 관계를 직접 설계하고, AI의 도움을 받아 구매·전투·보상 저장 프로시저와 FastAPI·JavaScript 웹 게임을 구현했습니다. SQL Server에서 트랜잭션·인덱스·백업·복원·동시성 문제를 직접 실습하고 검증했습니다. 특히 사냥 기록 조회의 논리적 읽기 449회와 3회를 비교하고, Blocking·Deadlock 재현 및 전투 보상 정합성을 확인했습니다.

## 8. 참고 자료

- [README 및 실행 방법](../README.md)
- [SQL 스키마·프로시저·검증 파일](../database/)
- [실행 결과 스크린샷](../screenshots/)
- [FastAPI 및 웹 게임 코드](../backend/)
