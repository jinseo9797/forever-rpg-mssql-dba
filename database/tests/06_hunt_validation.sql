USE ForeverRPG;
GO

-- V003 이후에는 승리한 전투만 사냥 보상 지급
-- 예전 usp_HuntMonster 직접 호출은 차단되어야 함

-- 활성 몬스터 목록
SELECT MonsterId,MonsterName,MonsterLevel,MaxHP,RewardGold
FROM dbo.Monsters
WHERE IsActive=1
ORDER BY MonsterId;
GO

-- 승리 전투 없이 보상 받기 시도: 오류 50107 예상
BEGIN TRY
    EXEC dbo.usp_HuntMonster @CharacterId=1,@MonsterId=1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber,ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO

-- 현재 캐릭터 골드 및 사냥 기록 확인
SELECT CharacterId,CharacterName,Gold FROM dbo.Characters WHERE CharacterId=1;
SELECT TOP(5) HuntId,CharacterId,MonsterId,EarnedGold,HuntedAt
FROM dbo.HuntHistory WHERE CharacterId=1 ORDER BY HuntId DESC;
GO

-- 실제 승리 보상은 V003 전투 시작/공격을 통해 확인
-- database/tests/07_battle_validation.sql 참고
