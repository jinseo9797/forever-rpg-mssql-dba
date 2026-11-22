USE ForeverRPG;
GO

-- 몬스터 사냥 보상 지급 및 이력 기록
CREATE OR ALTER PROCEDURE dbo.usp_HuntMonster
    @CharacterId INT,
    @MonsterId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentGold INT;
    DECLARE @RewardGold INT;
    DECLARE @MonsterName NVARCHAR(100);
    DECLARE @IsActive BIT;
    DECLARE @HuntId BIGINT;

    BEGIN TRY
        -- 입력값 확인
        IF @CharacterId IS NULL OR @CharacterId <= 0
           OR @MonsterId IS NULL OR @MonsterId <= 0
            THROW 50101, N'캐릭터와 몬스터 ID는 1 이상이어야 합니다.', 1;

        BEGIN TRAN;

        -- 골드 변경 대상 잠금
        SELECT @CurrentGold = Gold
        FROM dbo.Characters WITH (UPDLOCK, HOLDLOCK)
        WHERE CharacterId = @CharacterId;

        IF @CurrentGold IS NULL
            THROW 50102, N'존재하지 않는 캐릭터입니다.', 1;

        -- 몬스터 보상 및 활성 상태 확인
        SELECT
            @RewardGold = RewardGold,
            @MonsterName = MonsterName,
            @IsActive = IsActive
        FROM dbo.Monsters WITH (HOLDLOCK)
        WHERE MonsterId = @MonsterId;

        IF @RewardGold IS NULL OR @IsActive <> 1 OR @IsActive IS NULL
            THROW 50103, N'사냥할 수 없는 몬스터입니다.', 1;

        IF @RewardGold < 0
            THROW 50104, N'몬스터 보상 설정이 올바르지 않습니다.', 1;

        -- INT 골드 최대값 초과 방지
        IF @CurrentGold > 2147483647 - @RewardGold
            THROW 50105, N'보유 골드 최대치를 초과합니다.', 1;

        -- 골드 증가
        UPDATE dbo.Characters
        SET Gold = Gold + @RewardGold
        WHERE CharacterId = @CharacterId;

        IF @@ROWCOUNT <> 1
            THROW 50106, N'골드 지급에 실패했습니다.', 1;

        -- 사냥 이력 생성
        INSERT INTO dbo.HuntHistory (
            CharacterId, MonsterId, EarnedGold
        )
        VALUES (
            @CharacterId, @MonsterId, @RewardGold
        );

        SET @HuntId = CAST(SCOPE_IDENTITY() AS BIGINT);

        COMMIT TRAN;

        SELECT
            @HuntId AS HuntId,
            @CharacterId AS CharacterId,
            @MonsterId AS MonsterId,
            @MonsterName AS MonsterName,
            @RewardGold AS EarnedGold,
            @CurrentGold + @RewardGold AS CurrentGold,
            N'사냥 성공' AS ResultMessage;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        THROW;
    END CATCH;
END;
GO
