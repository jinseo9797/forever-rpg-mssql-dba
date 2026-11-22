USE ForeverRPG;
GO

-- 캐릭터의 전투 상태 생성, 기존 진행 중인 전투는 유지
CREATE OR ALTER PROCEDURE dbo.usp_StartBattle
    @CharacterId INT,
    @MonsterId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Level INT,@MaxHP INT,@Active BIT,@BattleId BIGINT;
    BEGIN TRY
        BEGIN TRAN;

        -- 동일 캐릭터 중복 전투 시작 직렬화
        SELECT @Level=CharacterLevel
        FROM dbo.Characters WITH (UPDLOCK,HOLDLOCK)
        WHERE CharacterId=@CharacterId;

        IF @Level IS NULL
            THROW 50201, N'존재하지 않는 캐릭터입니다.', 1;

        SELECT @BattleId=BattleId
        FROM dbo.BattleEncounters WITH (UPDLOCK,HOLDLOCK)
        WHERE CharacterId=@CharacterId AND Status='Active';

        IF @BattleId IS NOT NULL
        BEGIN
            -- 기존 전투를 새로 만들지 않고 반환
            SELECT @BattleId AS BattleId;
            COMMIT TRAN;
            RETURN;
        END;

        SELECT @MaxHP=MaxHP,@Active=IsActive
        FROM dbo.Monsters
        WHERE MonsterId=@MonsterId;

        IF @MaxHP IS NULL OR @Active<>1
            THROW 50202, N'사냥할 수 없는 몬스터입니다.', 1;

        INSERT dbo.BattleEncounters(CharacterId,MonsterId,PlayerHP,MonsterHP)
        VALUES(@CharacterId,@MonsterId,100+@Level*10,@MaxHP);

        SET @BattleId=CONVERT(BIGINT,SCOPE_IDENTITY());
        COMMIT TRAN;
        SELECT @BattleId AS BattleId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
