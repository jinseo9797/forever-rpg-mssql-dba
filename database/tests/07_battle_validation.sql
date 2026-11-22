USE ForeverRPG;
GO

-- 사전 점검: DB 버전과 전투 프로시저 확인
SELECT VersionNumber,AppliedAt FROM dbo.SchemaVersions
WHERE VersionNumber='V003';

SELECT name FROM sys.procedures
WHERE name IN ('usp_StartBattle','usp_AttackBattle','usp_HuntMonster');
GO

-- 캐릭터·활성 몬스터 확인
SELECT CharacterId,CharacterName,CharacterLevel,Gold
FROM dbo.Characters WHERE CharacterId=1;

SELECT MonsterId,MonsterName,MonsterLevel,MaxHP,RewardGold
FROM dbo.Monsters WHERE IsActive=1 ORDER BY MonsterId;
GO

-- 아래 예시는 MonsterId=1이 활성 상태일 때만 사용
-- 실습 시 BattleId는 실제 실행 결과로 확인
-- EXEC dbo.usp_StartBattle @CharacterId=1,@MonsterId=1;
-- GO

-- 공격은 실제 BattleId로 여러 번 나누어 실행
-- EXEC dbo.usp_AttackBattle @CharacterId=1,@BattleId=<실제 BattleId>;
-- GO

-- 전투 상태 및 보상 지급 여부 확인
SELECT TOP (10)
    BattleId,CharacterId,MonsterId,
    PlayerHP,MonsterHP,TurnCount,Status,RewardClaimed
FROM dbo.BattleEncounters
WHERE CharacterId=1
ORDER BY BattleId DESC;

-- 최근 기록, 골드 확인
SELECT CharacterId,Gold FROM dbo.Characters WHERE CharacterId=1;

SELECT TOP(10) HuntId,CharacterId,MonsterId,EarnedGold,HuntedAt
FROM dbo.HuntHistory WHERE CharacterId=1 ORDER BY HuntId DESC;
GO

-- 검증 목표
-- 1) 진행 중: Status=Active, RewardClaimed=0
-- 2) 승리: Status=Won, RewardClaimed=1, 사냥 이력 한 건 추가
-- 3) 동일 전투 재공격: 오류 50204
-- 4) 직접 usp_HuntMonster 호출: 오류 50107 또는 50108
