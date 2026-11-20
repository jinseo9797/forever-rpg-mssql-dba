USE master;
GO

SET NOCOUNT ON;

-- 원본과 복원본 상태 확인
SELECT
    name AS DatabaseName,
    state_desc AS DatabaseState
FROM sys.databases
WHERE name IN ('ForeverRPG', 'ForeverRPG_RestoreTest');
GO

-- 테이블별 원본·복원본 행 수 비교
-- 백업 이후 원본 DB가 변경되면 건수가 다를 수 있음
;WITH DataCounts AS (
    SELECT 'Characters' AS TableName,
        (SELECT COUNT(*) FROM ForeverRPG.dbo.Characters) AS OriginalCount,
        (SELECT COUNT(*) FROM ForeverRPG_RestoreTest.dbo.Characters) AS RestoredCount
    UNION ALL
    SELECT 'Items',
        (SELECT COUNT(*) FROM ForeverRPG.dbo.Items),
        (SELECT COUNT(*) FROM ForeverRPG_RestoreTest.dbo.Items)
    UNION ALL
    SELECT 'Monsters',
        (SELECT COUNT(*) FROM ForeverRPG.dbo.Monsters),
        (SELECT COUNT(*) FROM ForeverRPG_RestoreTest.dbo.Monsters)
    UNION ALL
    SELECT 'Inventory',
        (SELECT COUNT(*) FROM ForeverRPG.dbo.Inventory),
        (SELECT COUNT(*) FROM ForeverRPG_RestoreTest.dbo.Inventory)
    UNION ALL
    SELECT 'PurchaseHistory',
        (SELECT COUNT(*) FROM ForeverRPG.dbo.PurchaseHistory),
        (SELECT COUNT(*) FROM ForeverRPG_RestoreTest.dbo.PurchaseHistory)
    UNION ALL
    SELECT 'HuntHistory',
        (SELECT COUNT(*) FROM ForeverRPG.dbo.HuntHistory),
        (SELECT COUNT(*) FROM ForeverRPG_RestoreTest.dbo.HuntHistory)
    UNION ALL
    SELECT 'SchemaVersions',
        (SELECT COUNT(*) FROM ForeverRPG.dbo.SchemaVersions),
        (SELECT COUNT(*) FROM ForeverRPG_RestoreTest.dbo.SchemaVersions)
)
SELECT
    TableName,
    OriginalCount,
    RestoredCount,
    CASE WHEN OriginalCount = RestoredCount
        THEN 'PASS' ELSE 'FAIL'
    END AS TestResult
FROM DataCounts
ORDER BY TableName;
GO

-- 복원본 패치 이력 확인
SELECT
    VersionNumber,
    Description,
    ScriptName,
    AppliedAt
FROM ForeverRPG_RestoreTest.dbo.SchemaVersions
ORDER BY VersionNumber;
GO

-- 복원된 프로시저 확인
SELECT name AS ProcedureName
FROM ForeverRPG_RestoreTest.sys.procedures
WHERE name IN ('usp_GetCharacter', 'usp_GetItem', 'usp_PurchaseItem')
ORDER BY name;
GO

-- 복원본 V002 컬럼 구조 확인
USE ForeverRPG_RestoreTest;
GO
SELECT
    name AS ColumnName,
    TYPE_NAME(system_type_id) AS DataType,
    scale AS DateTimePrecision,
    is_nullable AS IsNullable
FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.Characters')
  AND name = 'LastLoginAt';
GO

-- 주의: 행 수 일치는 모든 데이터 값의 일치를 보장하지 않음
