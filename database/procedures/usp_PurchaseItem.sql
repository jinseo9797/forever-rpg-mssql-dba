
USE ForeverRPG;
GO

-- 아이템 구매 Stored Procedure
-- 골드 차감 / 인벤토리 지급 / 구매 이력 기록
CREATE OR ALTER PROCEDURE dbo.usp_PurchaseItem
    @CharacterId INT,
    @ItemId INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 구매 정보 변수
    DECLARE @UnitPrice INT;
    DECLARE @TotalPrice BIGINT;
    DECLARE @CurrentGold INT;
    DECLARE @IsAvailable BIT;

    BEGIN TRY

        -- 구매 수량 검증
        IF @Quantity IS NULL OR @Quantity <= 0
            THROW 50001, N'구매 수량은 1 이상이어야 합니다.', 1;

        BEGIN TRAN;

        -- 캐릭터 조회 및 잠금
        SELECT @CurrentGold = Gold
        FROM dbo.Characters WITH (UPDLOCK, HOLDLOCK)
        WHERE CharacterId = @CharacterId;

        -- 캐릭터 존재 여부 확인
        IF @CurrentGold IS NULL
            THROW 50002, N'존재하지 않는 캐릭터입니다.', 1;

        -- 아이템 가격 및 판매 상태 확인
        SELECT
            @UnitPrice = Price,
            @IsAvailable = IsAvailable
        FROM dbo.Items WITH (HOLDLOCK)
        WHERE ItemId = @ItemId;

        -- 구매 가능 여부 확인
        IF @UnitPrice IS NULL OR @IsAvailable IS NULL
           OR @IsAvailable <> 1
            THROW 50003, N'구매할 수 없는 아이템입니다.', 1;

        -- 총 구매 금액 계산
        SET @TotalPrice = CAST(@UnitPrice AS BIGINT) * @Quantity;

        -- 골드 부족 여부 확인
        IF @TotalPrice > @CurrentGold
            THROW 50004, N'보유 골드가 부족합니다.', 1;

        -- 골드 차감
        UPDATE dbo.Characters
        SET Gold = Gold - CAST(@TotalPrice AS INT)
        WHERE CharacterId = @CharacterId
          AND Gold >= @TotalPrice;

        IF @@ROWCOUNT <> 1
            THROW 50005, N'골드 차감에 실패했습니다.', 1;

        -- 기존 아이템 보유 여부 확인
        IF EXISTS (
            SELECT 1
            FROM dbo.Inventory WITH (UPDLOCK, HOLDLOCK)
            WHERE CharacterId = @CharacterId
              AND ItemId = @ItemId
        )
        BEGIN

            -- 기존 아이템 수량 증가
            UPDATE dbo.Inventory
            SET Quantity = Quantity + @Quantity,
                UpdatedAt = SYSDATETIME()
            WHERE CharacterId = @CharacterId
              AND ItemId = @ItemId
              AND Quantity <= 2147483647 - @Quantity;

            IF @@ROWCOUNT <> 1
                THROW 50006, N'인벤토리 수량 변경에 실패했습니다.', 1;

        END
        ELSE
        BEGIN

            -- 신규 아이템 지급
            INSERT INTO dbo.Inventory (
                CharacterId,
                ItemId,
                Quantity
            )
            VALUES (
                @CharacterId,
                @ItemId,
                @Quantity
            );

        END;

        -- 구매 이력 저장
        INSERT INTO dbo.PurchaseHistory (
            CharacterId,
            ItemId,
            Quantity,
            UnitPrice,
            TotalPrice
        )
        VALUES (
            @CharacterId,
            @ItemId,
            @Quantity,
            @UnitPrice,
            @TotalPrice
        );

        -- 전체 작업 확정
        COMMIT TRAN;

        -- 구매 결과 반환
        SELECT
            @CharacterId AS CharacterId,
            @ItemId AS ItemId,
            @Quantity AS PurchasedQuantity,
            @TotalPrice AS TotalPrice,
            N'구매 성공' AS ResultMessage;

    END TRY
    BEGIN CATCH

        -- 오류 발생 시 트랜잭션 취소
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        -- 오류를 호출자에게 전달
        THROW;

    END CATCH;
END;
GO
