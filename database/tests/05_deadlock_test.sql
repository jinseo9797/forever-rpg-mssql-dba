/*
Day 5: Deadlock 재현
개발용 ForeverRPG 전용 — 캐릭터 2와 3 사용
세션 A / B / C를 각각 별도 SSMS 쿼리 창에서 실행
순서: 초기 확인 → A1 → B1 → A2(대기) → B2(1205) → A3/B3 → C 검증
서로 다른 단계의 SQL을 한 번에 실행하지 않음
*/

-- [사전 점검: 세션 C] 캐릭터 데이터 확인
USE ForeverRPG;
GO
SELECT CharacterId, CharacterName, Gold
FROM dbo.Characters
WHERE CharacterId IN (2, 3)
ORDER BY CharacterId;
GO

/*
[세션 A1] 캐릭터 2의 잠금 유지
USE ForeverRPG;
GO
SET XACT_ABORT OFF;
SET DEADLOCK_PRIORITY NORMAL;
SET LOCK_TIMEOUT -1;

BEGIN TRAN;

UPDATE dbo.Characters
SET Gold = Gold + 1
WHERE CharacterId = 2;

SELECT @@SPID AS SessionId, @@TRANCOUNT AS TransactionCount;
*/

/*
[세션 B1] 캐릭터 3의 잠금 유지
USE ForeverRPG;
GO
SET XACT_ABORT OFF;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT -1;

BEGIN TRAN;

UPDATE dbo.Characters
SET Gold = Gold + 1
WHERE CharacterId = 3;

SELECT @@SPID AS SessionId, @@TRANCOUNT AS TransactionCount;
*/

/*
[세션 A2] 세션 B1 실행 후 캐릭터 3 수정 시도 — 대기 발생
UPDATE dbo.Characters
SET Gold = Gold + 1
WHERE CharacterId = 3;
*/

/*
[세션 B2] 세션 A2 대기 중 캐릭터 2 수정 시도 — 오류 1205 예상
UPDATE dbo.Characters
SET Gold = Gold + 1
WHERE CharacterId = 2;
*/

/*
[세션 A3] 오류 1205가 발생하고 A2가 종료된 뒤 실행
IF @@TRANCOUNT > 0
    ROLLBACK TRAN;

SELECT @@SPID AS SessionId, @@TRANCOUNT AS TransactionCount;
*/

/*
[세션 B3] 오류 1205 발생 후 실행
IF @@TRANCOUNT > 0
    ROLLBACK TRAN;

SET DEADLOCK_PRIORITY NORMAL;
SET LOCK_TIMEOUT -1;

SELECT @@SPID AS SessionId, @@TRANCOUNT AS TransactionCount;
*/

/*
[세션 C] 양쪽 트랜잭션 종료 후 데이터 확인
USE ForeverRPG;
GO
SELECT CharacterId, CharacterName, Gold
FROM dbo.Characters
WHERE CharacterId IN (2, 3)
ORDER BY CharacterId;
*/

-- system_health 이벤트에 남은 교착 상태 XML 조회
USE master;
GO
SELECT TOP (10)
    CAST(F.event_data AS XML).value(
        '(/event/@timestamp)[1]', 'datetime2(3)'
    ) AS EventTimeUTC,
    CAST(F.event_data AS XML).query(
        '/event/data[@name="xml_report"]/value/deadlock'
    ) AS DeadlockGraph
FROM sys.fn_xe_file_target_read_file(
    'system_health*.xel', NULL, NULL, NULL
) AS F
WHERE F.object_name = 'xml_deadlock_report'
ORDER BY EventTimeUTC DESC;
GO
