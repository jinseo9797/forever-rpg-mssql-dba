USE ForeverRPG;
GO

-- 서버에서 검증된 승리 전투에 한해 보상 지급
-- 기존 무조건 보상 방식 대신 BattleId를 필수로 확인
CREATE OR ALTER PROCEDURE dbo.usp_HuntMonster
    @CharacterId INT,
    @MonsterId INT,
    @BattleId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentGold INT;
    DECLARE @RewardGold INT;
    DECLARE @MonsterName NVARCHAR(100);
    DECLARE @HuntId BIGINT;

    BEGIN TRY
        IF @BattleId IS NULL
            THROW 50107, N'승리한 전투 ID가 필요합니다.', 1;

        BEGIN TRAN;

        -- 같은 전투를 두 번 보상하지 못하도록 잠금
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.BattleEncounters WITH (UPDLOCK,HOLDLOCK)
            WHERE BattleId=@BattleId
              AND CharacterId=@CharacterId
              AND MonsterId=@MonsterId
              AND Status='Won'
              AND RewardClaimed=0
        )
            THROW 50108, N'승리 전투가 아니거나 보상이 이미 지급됐습니다.', 1;

        SELECT @CurrentGold=Gold
        FROM dbo.Characters WITH(UPDLOCK,HOLDLOCK)
        WHERE CharacterId=@CharacterId;

        IF @CurrentGold IS NULL
            THROW 50102, N'존재하지 않는 캐릭터입니다.', 1;

        SELECT @RewardGold=RewardGold, @MonsterName=MonsterName
        FROM dbo.Monsters WITH(HOLDLOCK)
        WHERE MonsterId=@MonsterId;

        IF @RewardGold IS NULL OR @RewardGold<0
            THROW 50104, N'몬스터 보상 설정이 올바르지 않습니다.', 1;

        IF @CurrentGold > 2147483647-@RewardGold
            THROW 50105, N'보유 골드 최대치를 초과합니다.', 1;

        UPDATE dbo.Characters
        SET Gold=Gold+@RewardGold
        WHERE CharacterId=@CharacterId;

        INSERT dbo.HuntHistory(CharacterId,MonsterId,EarnedGold)
        VALUES(@CharacterId,@MonsterId,@RewardGold);

        SET @HuntId=CONVERT(BIGINT,SCOPE_IDENTITY());

        UPDATE dbo.BattleEncounters
        SET RewardClaimed=1, UpdatedAt=SYSDATETIME()
        WHERE BattleId=@BattleId AND RewardClaimed=0;

        IF @@ROWCOUNT<>1
            THROW 50109, N'보상 처리 상태 갱신에 실패했습니다.', 1;

        COMMIT TRAN;

        -- 다른 프로시저 내부에서도 호출되므로 결과 집합은 반환하지 않음
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
