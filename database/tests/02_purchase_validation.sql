USE ForeverRPG;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- =====================================================
-- Forever RPG - Day 2
-- Stored Procedure 구매 및 트랜잭션 검증
--
-- TC-01: 정상 구매 및 데이터 정합성 검증
-- TC-02: 골드 부족 오류 검증
-- TC-03: 존재하지 않는 캐릭터 검증
-- TC-04: 잘못된 구매 수량 검증
-- TC-05: 트랜잭션 중간 실패 및 ROLLBACK 검증
--
-- 테스트 대상: CharacterId = 1, ItemId = 1
-- 개발용 DB에서 실행
-- =====================================================


-- =====================================================
-- TC-01. 정상 구매 검증
-- 외부 트랜잭션으로 테스트 결과 확인 후 ROLLBACK
-- =====================================================

DECLARE @CharacterId INT = 1;
DECLARE @ItemId INT = 1;
DECLARE @Quantity INT = 1;

DECLARE @BeforeGold INT;
DECLARE @AfterGold INT;
DECLARE @BeforeQuantity INT;
DECLARE @AfterQuantity INT;
DECLARE @BeforeCount INT;
DECLARE @AfterCount INT;
DECLARE @Price INT;
DECLARE @TotalPrice BIGINT;

SELECT @BeforeGold = Gold
FROM dbo.Characters
WHERE CharacterId = @CharacterId;

SELECT @Price = Price
FROM dbo.Items
WHERE ItemId = @ItemId
  AND IsAvailable = 1;

SELECT @BeforeQuantity = ISNULL((
    SELECT Quantity
    FROM dbo.Inventory
    WHERE CharacterId = @CharacterId
      AND ItemId = @ItemId
), 0);

SELECT @BeforeCount = COUNT(*)
FROM dbo.PurchaseHistory
WHERE CharacterId = @CharacterId;

SET @TotalPrice = CAST(@Price AS BIGINT) * @Quantity;

IF @BeforeGold IS NULL
   OR @Price IS NULL
   OR @BeforeGold < @TotalPrice
   OR @BeforeQuantity > 2147483647 - @Quantity
BEGIN
    PRINT N'TC-01 SKIP: 테스트 데이터 또는 골드 부족';
END
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;

        -- 정상 구매 실행
        EXEC dbo.usp_PurchaseItem
            @CharacterId = @CharacterId,
            @ItemId = @ItemId,
            @Quantity = @Quantity;

        -- 구매 후 데이터 조회
        SELECT @AfterGold = Gold
        FROM dbo.Characters
        WHERE CharacterId = @CharacterId;

        SELECT @AfterQuantity = ISNULL((
            SELECT Quantity
            FROM dbo.Inventory
            WHERE CharacterId = @CharacterId
              AND ItemId = @ItemId
        ), 0);

        SELECT @AfterCount = COUNT(*)
        FROM dbo.PurchaseHistory
        WHERE CharacterId = @CharacterId;

        -- 정상 구매 검증 결과
        SELECT
            'TC-01' AS TestCase,

            CASE
                WHEN @AfterGold = @BeforeGold - @TotalPrice
                THEN 'PASS' ELSE 'FAIL'
            END AS GoldTest,

            CASE
                WHEN @AfterQuantity = @BeforeQuantity + @Quantity
                THEN 'PASS' ELSE 'FAIL'
            END AS InventoryTest,

            CASE
                WHEN @AfterCount = @BeforeCount + 1
                THEN 'PASS' ELSE 'FAIL'
            END AS PurchaseHistoryTest;

        -- 구매 결과 원상복구
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        SELECT
            'TC-01' AS TestCase,
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            'FAIL' AS TestResult;
    END CATCH;
END;
GO


-- =====================================================
-- TC-02. 골드 부족 오류 검증
-- 오류 번호 50004 및 데이터 변경 여부 확인
-- =====================================================

DECLARE @BeforeGold INT;
DECLARE @AfterGold INT;
DECLARE @BeforeInventory INT;
DECLARE @AfterInventory INT;
DECLARE @BeforeCount INT;
DECLARE @AfterCount INT;
DECLARE @ErrorNumber INT = NULL;

-- 테스트 전 상태 저장
SELECT @BeforeGold = Gold
FROM dbo.Characters
WHERE CharacterId = 1;

SELECT @BeforeInventory = ISNULL(SUM(Quantity), 0)
FROM dbo.Inventory
WHERE CharacterId = 1;

SELECT @BeforeCount = COUNT(*)
FROM dbo.PurchaseHistory
WHERE CharacterId = 1;

BEGIN TRY
    -- 의도적인 골드 부족 요청
    EXEC dbo.usp_PurchaseItem
        @CharacterId = 1,
        @ItemId = 1,
        @Quantity = 2147483647;

END TRY
BEGIN CATCH
    SET @ErrorNumber = ERROR_NUMBER();
END CATCH;

-- 테스트 후 상태 저장
SELECT @AfterGold = Gold
FROM dbo.Characters
WHERE CharacterId = 1;

SELECT @AfterInventory = ISNULL(SUM(Quantity), 0)
FROM dbo.Inventory
WHERE CharacterId = 1;

SELECT @AfterCount = COUNT(*)
FROM dbo.PurchaseHistory
WHERE CharacterId = 1;

-- 골드 부족 검증
SELECT
    'TC-02' AS TestCase,

    CASE
        WHEN @ErrorNumber = 50004
        THEN 'PASS' ELSE 'FAIL'
    END AS ErrorTest,

    CASE
        WHEN @BeforeGold = @AfterGold
        THEN 'PASS' ELSE 'FAIL'
    END AS GoldTest,

    CASE
        WHEN @BeforeInventory = @AfterInventory
        THEN 'PASS' ELSE 'FAIL'
    END AS InventoryTest,

    CASE
        WHEN @BeforeCount = @AfterCount
        THEN 'PASS' ELSE 'FAIL'
    END AS PurchaseHistoryTest;
GO


-- =====================================================
-- TC-03. 존재하지 않는 캐릭터 검증
-- 오류 번호 50002 확인
-- =====================================================

DECLARE @ErrorNumber INT = NULL;

BEGIN TRY
    EXEC dbo.usp_PurchaseItem
        @CharacterId = 999999,
        @ItemId = 1,
        @Quantity = 1;
END TRY
BEGIN CATCH
    SET @ErrorNumber = ERROR_NUMBER();
END CATCH;

SELECT
    'TC-03' AS TestCase,
    @ErrorNumber AS ActualErrorNumber,

    CASE
        WHEN @ErrorNumber = 50002
        THEN 'PASS' ELSE 'FAIL'
    END AS TestResult;
GO


-- =====================================================
-- TC-04. 잘못된 구매 수량 검증
-- 오류 번호 50001 확인
-- =====================================================

DECLARE @ErrorNumber INT = NULL;

BEGIN TRY
    EXEC dbo.usp_PurchaseItem
        @CharacterId = 1,
        @ItemId = 1,
        @Quantity = -1;
END TRY
BEGIN CATCH
    SET @ErrorNumber = ERROR_NUMBER();
END CATCH;

SELECT
    'TC-04' AS TestCase,
    @ErrorNumber AS ActualErrorNumber,

    CASE
        WHEN @ErrorNumber = 50001
        THEN 'PASS' ELSE 'FAIL'
    END AS TestResult;
GO


-- =====================================================
-- TC-05. 트랜잭션 중간 실패 및 ROLLBACK 검증
-- 골드 차감 후 강제 오류 발생
-- 실제 인벤토리 지급은 수행하지 않음
-- =====================================================

DECLARE @BeforeGold INT;
DECLARE @AfterGold INT;
DECLARE @ErrorNumber INT = NULL;

-- 변경 전 골드 저장
SELECT @BeforeGold = Gold
FROM dbo.Characters
WHERE CharacterId = 1;

IF @BeforeGold IS NULL OR @BeforeGold < 1
BEGIN
    PRINT N'TC-05 SKIP: 캐릭터가 없거나 골드 부족';
END
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;

        -- 골드 1 차감
        UPDATE dbo.Characters
        SET Gold = Gold - 1
        WHERE CharacterId = 1
          AND Gold >= 1;

        IF @@ROWCOUNT <> 1
            THROW 50010, N'골드 차감 실패', 1;

        -- 강제로 트랜잭션 중간 실패 재현
        THROW 50011, N'트랜잭션 중간 실패 테스트', 1;

        COMMIT TRAN;

    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();

        -- 차감된 골드 복구
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;
    END CATCH;

    -- ROLLBACK 이후 골드 확인
    SELECT @AfterGold = Gold
    FROM dbo.Characters
    WHERE CharacterId = 1;

    SELECT
        'TC-05' AS TestCase,
        @ErrorNumber AS ActualErrorNumber,

        CASE
            WHEN @ErrorNumber = 50011
             AND @BeforeGold = @AfterGold
             AND @@TRANCOUNT = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END AS RollbackTest,

        @BeforeGold AS BeforeGold,
        @AfterGold AS AfterGold;
END;
GO