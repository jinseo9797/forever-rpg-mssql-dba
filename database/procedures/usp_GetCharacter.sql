
USE ForeverRPG;
GO

-- 캐릭터 ID를 기준으로 캐릭터 정보 조회
CREATE OR ALTER PROCEDURE dbo.usp_GetCharacter
    @CharacterId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CharacterId,
        CharacterName,
        ClassName,
        CharacterLevel,
        Gold
    FROM dbo.Characters
    WHERE CharacterId = @CharacterId;
END;
GO
