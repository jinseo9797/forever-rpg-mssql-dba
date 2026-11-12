
/*
    Project  : Forever RPG
    Database : ForeverRPG
    Purpose  : Day 1 Schema Validation
*/

USE ForeverRPG;
GO

-- =====================================================
-- 01. 테이블 목록 및 컬럼 개수 확인
-- =====================================================

SELECT
    t.name AS TableName,
    COUNT(c.column_id) AS ColumnCount
FROM sys.tables AS t
INNER JOIN sys.columns AS c
    ON t.object_id = c.object_id
WHERE SCHEMA_NAME(t.schema_id) = 'dbo'
GROUP BY t.name
ORDER BY t.name;
GO

-- =====================================================
-- 02. 외래키 관계 확인
-- =====================================================

SELECT
    fk.name AS ForeignKeyName,
    OBJECT_NAME(fk.parent_object_id) AS ChildTable,
    OBJECT_NAME(fk.referenced_object_id) AS ParentTable
FROM sys.foreign_keys AS fk
ORDER BY ChildTable, ForeignKeyName;
GO

-- =====================================================
-- 03. CHECK 제약조건 확인
-- =====================================================

SELECT
    OBJECT_NAME(parent_object_id) AS TableName,
    name AS ConstraintName,
    definition AS CheckCondition
FROM sys.check_constraints
ORDER BY TableName, ConstraintName;
GO

-- =====================================================
-- 04. UNIQUE 제약조건 확인
-- =====================================================

SELECT
    OBJECT_NAME(kc.parent_object_id) AS TableName,
    kc.name AS ConstraintName,
    kc.type_desc AS ConstraintType
FROM sys.key_constraints AS kc
WHERE kc.type = 'UQ'
ORDER BY TableName, ConstraintName;
GO

-- =====================================================
-- 05. DB 패치 버전 확인
-- =====================================================

SELECT
    VersionNumber,
    Description,
    ScriptName,
    AppliedAt,
    AppliedBy
FROM dbo.SchemaVersions
ORDER BY VersionId;
GO

-- =====================================================
-- 06. 검증 결과 요약
-- =====================================================

SELECT
    (SELECT COUNT(*)
     FROM sys.tables
     WHERE schema_id = SCHEMA_ID('dbo')) AS TableCount,

    (SELECT COUNT(*)
     FROM sys.foreign_keys
     WHERE schema_id = SCHEMA_ID('dbo')) AS ForeignKeyCount,

    (SELECT COUNT(*)
     FROM sys.check_constraints
     WHERE schema_id = SCHEMA_ID('dbo')) AS CheckCount,

    (SELECT COUNT(*)
     FROM sys.key_constraints
     WHERE type = 'UQ'
       AND schema_id = SCHEMA_ID('dbo')) AS UniqueCount;
GO
