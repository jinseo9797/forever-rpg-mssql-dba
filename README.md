# Forever RPG
### Microsoft SQL Server 기반 RPG 데이터베이스 설계 및 운영 프로젝트

Forever RPG는 RPG 게임의 캐릭터, 아이템, 몬스터, 인벤토리 및 게임 활동 기록을 관리하는 **Microsoft SQL Server 기반 데이터베이스 프로젝트**입니다.

게임 서비스에서 발생하는 데이터의 생성·변경·조회 과정을 구현하고, 데이터 정합성 검증부터 Stored Procedure, 트랜잭션 처리, 성능 최적화, 데이터베이스 패치 및 복구까지 단계적으로 실습하는 것을 목표로 합니다.

프론트엔드와 백엔드는 AI를 활용하여 구현하며, SQL Server 기반 데이터베이스의 검증·운영·최적화 과정에 집중합니다.

---

## 1. 프로젝트 목표

- **데이터베이스 설계:** RPG 게임 데이터를 관계형 테이블로 구성하고 PK, FK, UNIQUE, CHECK 제약조건을 활용한 데이터 무결성 확보
- **Stored Procedure:** T-SQL을 활용한 캐릭터 생성, 아이템 구매 및 사냥 보상 처리
- **트랜잭션:** 골드 차감과 아이템 지급 과정에서 발생할 수 있는 데이터 불일치 방지
- **성능 최적화:** 실행 계획과 STATISTICS IO를 활용한 인덱스 적용 전후 성능 비교
- **DB 운영:** SQL 스크립트 버전 관리, 패치 검수, 백업 및 복원 실습

## 2. 기술 스택

| 구분 | 기술 |
|---|---|
| Database | Microsoft SQL Server |
| SQL | T-SQL |
| DB Management | SQL Server Management Studio (SSMS) |
| Backend | Python, FastAPI (예정) |
| Frontend | HTML, CSS, JavaScript (예정) |
| Version Control | Git, GitHub |

## 3. 시스템 아키텍처

향후 구현할 웹 애플리케이션의 구조입니다.

```text
[ RPG Web Client ]
        |
        v
[ FastAPI Backend ]
        |
        v
[ SQL Server / Stored Procedures ]
        |
        v
[ ForeverRPG Database ]
```

게임에서 발생하는 골드 변경, 아이템 지급 및 구매 이력 저장은 데이터베이스 트랜잭션을 통해 처리할 예정입니다.

## 4. 데이터베이스 설계

### 주요 테이블

| 테이블 | 역할 |
|---|---|
| Characters | 캐릭터 정보, 레벨 및 골드 관리 |
| Items | 아이템 정보, 가격 및 판매 여부 |
| Monsters | 몬스터 정보 및 사냥 보상 |
| Inventory | 캐릭터별 보유 아이템 및 수량 |
| PurchaseHistory | 아이템 구매 내역과 구매 당시 가격 |
| HuntHistory | 몬스터 사냥 이력 및 실제 획득 골드 |
| SchemaVersions | 데이터베이스 패치 및 버전 이력 |

### 주요 설계 특징

**1. 참조 무결성**

Inventory, PurchaseHistory, HuntHistory에 Foreign Key를 설정하여 존재하지 않는 캐릭터, 아이템 및 몬스터를 참조하는 데이터 입력을 방지합니다.

**2. 데이터 정합성**

CHECK 제약조건으로 음수 골드 및 잘못된 수량 입력을 제한하고, 구매 총액이 단가와 수량의 곱과 일치하도록 검증합니다.

**3. 이력 데이터 보존**

아이템 가격과 몬스터 보상이 변경되더라도 과거 거래 및 사냥 기록을 유지할 수 있도록 당시의 가격과 실제 지급 보상을 별도 컬럼으로 저장합니다.

**4. 데이터베이스 버전 관리**

SchemaVersions 테이블과 버전별 SQL 스크립트를 활용하여 데이터베이스 변경 이력을 관리합니다. 향후 Stored Procedure 수정과 DB 패치에도 버전 관리를 적용할 계획입니다.

## 5. 실행 환경 및 초기 설정

### 개발 환경

- Microsoft SQL Server
- SQL Server Management Studio (SSMS)

### 데이터베이스 생성

SQL Server에 접속한 후 다음 SQL을 실행합니다.

```sql
CREATE DATABASE ForeverRPG;
GO
```

데이터베이스 생성이 완료되면 다음 파일을 SSMS에서 실행합니다.

**[V001__init_schema.sql](database/migrations/V001__init_schema.sql)**

해당 스크립트는 총 7개의 테이블과 초기 스키마 버전 정보(V001)를 생성합니다.

> **주의:** V001 스크립트는 신규 데이터베이스에서 최초 1회 실행하는 용도입니다. 기존 테이블이 존재하는 데이터베이스에서는 중복 생성 오류가 발생할 수 있습니다.

### 스키마 검증

초기 스키마 생성 후 다음 검증 SQL을 실행합니다.

**[01_schema_validation.sql](database/tests/01_schema_validation.sql)**

이 스크립트는 테이블, 외래키, CHECK 및 UNIQUE 제약조건, 스키마 버전 정보를 조회합니다.

## 6. 개발 로드맵

| 단계 | 작업 내용 | 상태 |
|---|---|---|
| Day 1 | 데이터베이스 테이블 설계 및 검증 | 완료 |
| Day 2 | Stored Procedure 및 트랜잭션 구현 | 예정 |
| Day 3 | 대량 로그 기반 쿼리 성능 최적화 | 예정 |
| Day 4 | DB 패치, 버전 관리, 백업 및 복원 | 예정 |
| Day 5 | 장애 대응 시나리오 및 최종 검증 | 예정 |

### Day 1 — Database Schema Design

게임 데이터 관리를 위한 7개 테이블의 초기 구조를 구현했습니다.

주요 작업은 다음과 같습니다.

- Characters, Items, Monsters 기본 데이터 테이블 구성
- Inventory, PurchaseHistory, HuntHistory 관계 설정
- 기본키 및 외래키를 통한 참조 무결성 관리
- UNIQUE, CHECK, DEFAULT를 활용한 데이터 제약조건 구성
- SchemaVersions를 활용한 초기 DB 버전 관리 구조 마련
- SQL Server 시스템 카탈로그를 이용한 스키마 검증

### Day 1 스키마 검증 결과

| 검증 항목 | 결과 |
|---|---:|
| 생성 테이블 | 7개 |
| Foreign Key | 6개 |
| CHECK 제약조건 | 11개 |
| UNIQUE 제약조건 | 3개 |
| 초기 스키마 버전 | V001 |

SQL Server 시스템 카탈로그를 조회하여 테이블 및 제약조건 구성을 확인했습니다.

이는 스키마 구성 검증 결과이며, 실제 트랜잭션 및 동시성 처리는 후속 단계에서 검증할 예정입니다.

**관련 파일**

- [초기 데이터베이스 생성 SQL](database/migrations/V001__init_schema.sql)
- [스키마 검증 SQL](database/tests/01_schema_validation.sql)
- [Day 1 데이터베이스 설계 기록](docs/day01_database_design.md)

## 7. 향후 개발 계획

### Day 2 — Stored Procedures & Transactions

아이템 구매 시 골드 차감, 인벤토리 갱신, 구매 기록 저장을 하나의 트랜잭션으로 처리합니다.

트랜잭션 중 오류가 발생하면 ROLLBACK을 통해 데이터 정합성을 보장하는 기능을 구현할 예정입니다.

### Day 3 — Query Performance Optimization

대량의 구매 및 사냥 로그를 생성하고 실행 계획과 논리적 읽기를 비교하여 인덱스 적용 효과를 측정합니다.

### Day 4 — Database Patching & Recovery

데이터베이스 변경 스크립트를 버전별로 관리하고, 변경 사항 검증 및 백업·복원 과정을 실습합니다.

### Day 5 — Troubleshooting

게임 서비스 장애를 가정하여 문제 재현, SQL 분석, 원인 파악, 개선 및 재검증 과정을 기록합니다.

---

## 8. AI 활용 및 기여 범위

본 프로젝트는 AI를 개발 보조 도구로 활용합니다.

- **AI 지원:** 초기 데이터베이스 DDL 작성, 프론트엔드 및 백엔드 코드 작성, 문서 구성
- **직접 수행 완료:** SQL Server 환경에서 테이블 생성, 쿼리 실행 및 스키마 구조 검증
- **직접 수행 예정:** Stored Procedure 실습, 트랜잭션 테스트, 실행 계획 분석, 인덱스 튜닝, DB 패치 및 복구 검증

최종 분석 결과와 운영 테스트는 직접 수행한 검증 내용을 기준으로 기록합니다.
