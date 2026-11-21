/*
Day 5: Blocking 재현 및 해소 검증
개발용 ForeverRPG에서만 실행
각 구간을 SSMS의 별도 연결(세션 A/B/C)에 복사하여 실행
실행 순서: A 잠금 유지 → B UPDATE 대기 → C 감지 → A ROLLBACK → C 재검증
주의: 세션 B의 UPDATE가 성공하면 Gold가 1 증가할 수 있음
*/

-- [세션 A] 트랜잭션을 열어 잠금 유지
USE ForeverRPG;
GO
SELECT @@SPID AS SessionId;
BEGIN TRAN;
UPDATE dbo.Characters
SET Gold = Gold + 1
WHERE CharacterId = 1;
SELECT @@TRANCOUNT AS TransactionCount;
-- 세션 C 확인 전 COMMIT 또는 ROLLBACK 금지

/*
[세션 B] 반드시 다른 SSMS 연결에서 실행
세션 A가 트랜잭션을 유지할 때 실행
*/
-- USE ForeverRPG;
-- GO
-- SELECT @@SPID AS SessionId;
-- SET LOCK_TIMEOUT 60000;
-- UPDATE dbo.Characters
-- SET Gold = Gold + 1
-- WHERE CharacterId = 1;
-- GO
-- SET LOCK_TIMEOUT -1;

/*
[세션 C] 세션 B가 대기 중일 때 별도 연결에서 실행
*/
-- USE master;
-- GO
-- SELECT
--     session_id AS SessionId,
--     blocking_session_id AS BlockingSessionId,
--     wait_type AS WaitType,
--     wait_time AS WaitTimeMs,
--     wait_resource AS WaitResource,
--     status AS SessionStatus
-- FROM sys.dm_exec_requests
-- WHERE blocking_session_id > 0;

/*
[세션 A] 세션 C에서 감지 결과를 촬영한 뒤 실행
*/
-- ROLLBACK TRAN;
-- SELECT @@SPID AS SessionId, @@TRANCOUNT AS TransactionCount;

/*
[세션 C] 세션 A의 ROLLBACK 후 실행
*/
-- SELECT
--     session_id AS SessionId,
--     blocking_session_id AS BlockingSessionId,
--     wait_type AS WaitType
-- FROM sys.dm_exec_requests
-- WHERE blocking_session_id > 0;

/*
[세션 B] UPDATE가 완료되거나 오류가 난 뒤 설정 초기화
*/
-- SET LOCK_TIMEOUT -1;
-- SELECT @@TRANCOUNT AS TransactionCount;

-- 검증 후 Gold 값을 확인하고, 필요 시 별도의 안전한 절차로 복구
-- SELECT CharacterId, Gold FROM ForeverRPG.dbo.Characters WHERE CharacterId = 1;
