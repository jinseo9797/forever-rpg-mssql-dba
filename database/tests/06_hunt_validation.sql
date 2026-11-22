USE ForeverRPG;
GO

-- 사냥 테스트 전 몬스터 목록 확인
SELECT MonsterId, MonsterName, RewardGold, IsActive
FROM dbo.Monsters
ORDER BY MonsterId;
GO

-- 정상 사냥 전 캐릭터 상태 확인
SELECT CharacterId, CharacterName, Gold
FROM dbo.Characters
WHERE CharacterId = 1;
GO

/*
아래 ID를 위 조회 결과의 활성 몬스터로 바꾼 뒤 별도로 실행
정상 사냥은 실제 골드와 HuntHistory를 변경
*/
-- EXEC dbo.usp_HuntMonster @CharacterId = 1, @MonsterId = 1;
-- GO

-- 정상 사냥 후 결과 검증
SELECT CharacterId, CharacterName, Gold
FROM dbo.Characters
WHERE CharacterId = 1;

SELECT TOP (5) HuntId, CharacterId, MonsterId, EarnedGold, HuntedAt
FROM dbo.HuntHistory
WHERE CharacterId = 1
ORDER BY HuntId DESC;
GO

-- 잘못된 캐릭터 ID: 오류 50102 예상, 보상 미지급
BEGIN TRY
    EXEC dbo.usp_HuntMonster @CharacterId = -1, @MonsterId = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO
