USE ForeverRPG;
GO
SET XACT_ABORT ON;
GO

-- V003: 서버에서 전투 상태 및 보상 지급 여부 관리
BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber='V002')
        THROW 50300, N'V002 적용 후 실행해야 합니다.', 1;

    IF OBJECT_ID(N'dbo.BattleEncounters', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.BattleEncounters (
            BattleId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_BattleEncounters PRIMARY KEY,
            CharacterId INT NOT NULL,
            MonsterId INT NOT NULL,
            PlayerHP INT NOT NULL,
            MonsterHP INT NOT NULL,
            TurnCount INT NOT NULL CONSTRAINT DF_Battle_Turn DEFAULT(0),
            Status VARCHAR(12) NOT NULL CONSTRAINT DF_Battle_Status DEFAULT('Active'),
            RewardClaimed BIT NOT NULL CONSTRAINT DF_Battle_RewardClaimed DEFAULT(0),
            CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_Battle_CreatedAt DEFAULT(SYSDATETIME()),
            UpdatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_Battle_UpdatedAt DEFAULT(SYSDATETIME()),
            CONSTRAINT FK_Battle_Character FOREIGN KEY(CharacterId) REFERENCES dbo.Characters(CharacterId),
            CONSTRAINT FK_Battle_Monster FOREIGN KEY(MonsterId) REFERENCES dbo.Monsters(MonsterId),
            CONSTRAINT CK_Battle_HP CHECK(PlayerHP >= 0 AND MonsterHP >= 0),
            CONSTRAINT CK_Battle_TurnCount CHECK(TurnCount >= 0),
            CONSTRAINT CK_Battle_Status CHECK(Status IN ('Active','Won','Lost')),
            CONSTRAINT CK_Battle_Claim CHECK(RewardClaimed=0 OR Status='Won')
        );

        CREATE UNIQUE INDEX UX_Battle_ActiveCharacter
        ON dbo.BattleEncounters(CharacterId) WHERE Status='Active';
    END;

    IF NOT EXISTS(SELECT 1 FROM dbo.SchemaVersions WITH (UPDLOCK,HOLDLOCK) WHERE VersionNumber='V003')
        INSERT dbo.SchemaVersions(VersionNumber,Description,ScriptName)
        VALUES('V003',N'전투 상태 및 사냥 보상 중복 지급 방지',N'V003__add_battle_encounters.sql');

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO
