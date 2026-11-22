USE ForeverRPG;
GO

-- 단일 턴 처리: 전투 행 잠금 -> HP 계산 -> 승리 시 보상 프로시저 호출
CREATE OR ALTER PROCEDURE dbo.usp_AttackBattle
    @CharacterId INT,
    @BattleId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MonsterId INT,@PlayerHP INT,@MonsterHP INT,@Level INT,@MonsterLevel INT,
        @Damage INT,@CounterDamage INT,@Status VARCHAR(12),@RewardClaimed BIT;

    BEGIN TRY
        BEGIN TRAN;

        SELECT @MonsterId=MonsterId,@PlayerHP=PlayerHP,
               @MonsterHP=MonsterHP,@Status=Status,@RewardClaimed=RewardClaimed
        FROM dbo.BattleEncounters WITH (UPDLOCK,HOLDLOCK)
        WHERE BattleId=@BattleId AND CharacterId=@CharacterId;

        IF @MonsterId IS NULL
            THROW 50203, N'존재하지 않는 전투입니다.', 1;
        IF @Status<>'Active'
            THROW 50204, N'이미 종료된 전투입니다.', 1;

        SELECT @Level=CharacterLevel FROM dbo.Characters WHERE CharacterId=@CharacterId;
        SELECT @MonsterLevel=MonsterLevel FROM dbo.Monsters WHERE MonsterId=@MonsterId;

        -- 초급 턴제 규칙: 서버에서만 공격력 계산
        SET @Damage=10+@Level*3;
        SET @CounterDamage=5+@MonsterLevel*2;
        SET @MonsterHP=CASE WHEN @MonsterHP>@Damage THEN @MonsterHP-@Damage ELSE 0 END;

        IF @MonsterHP=0
            SET @Status='Won';
        ELSE
        BEGIN
            SET @PlayerHP=CASE WHEN @PlayerHP>@CounterDamage
                THEN @PlayerHP-@CounterDamage ELSE 0 END;
            IF @PlayerHP=0 SET @Status='Lost';
        END;

        UPDATE dbo.BattleEncounters
        SET PlayerHP=@PlayerHP,MonsterHP=@MonsterHP,
            TurnCount=TurnCount+1,Status=@Status,UpdatedAt=SYSDATETIME()
        WHERE BattleId=@BattleId;

        -- 승리 시에만 같은 트랜잭션 안에서 보상 확정
        IF @Status='Won'
            EXEC dbo.usp_HuntMonster
                @CharacterId=@CharacterId,
                @MonsterId=@MonsterId,
                @BattleId=@BattleId;

        COMMIT TRAN;

        SELECT b.BattleId,b.CharacterId,b.MonsterId,m.MonsterName,
               b.PlayerHP,b.MonsterHP,b.TurnCount,b.Status,
               b.RewardClaimed,m.RewardGold,
               @Damage AS PlayerDamage,
               CASE WHEN @MonsterHP>0 THEN @CounterDamage ELSE 0 END AS MonsterDamage
        FROM dbo.BattleEncounters b
        JOIN dbo.Monsters m ON m.MonsterId=b.MonsterId
        WHERE b.BattleId=@BattleId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
