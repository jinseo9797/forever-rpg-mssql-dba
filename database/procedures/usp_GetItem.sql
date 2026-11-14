
USE ForeverRPG;
GO

-- 아이템 ID를 기준으로 아이템 정보 조회
CREATE OR ALTER PROCEDURE dbo.usp_GetItem
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ItemId,
        ItemName,
        ItemType,
        Price,
        IsAvailable
    FROM dbo.Items
    WHERE ItemId = @ItemId;
END;
GO
