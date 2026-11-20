USE ForeverRPG;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- V002: 캐릭터 마지막 접속 시각 컬럼 추가
-- 기존 컬럼이 있으면 구조 확인 후 패치 이력만 등록
BEGIN TRY
    BEGIN TRAN;

    -- 선행 버전 확인
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.SchemaVersions
        WHERE VersionNumber = 'V001'
    )
        THROW 50020, N'V001 버전이 존재하지 않습니다.', 1;

    -- 컬럼이 없으면 생성
    IF COL_LENGTH('dbo.Characters', 'LastLoginAt') IS NULL
    BEGIN
        ALTER TABLE dbo.Characters
        ADD LastLoginAt DATETIME2(3) NULL;
    END;

    -- 컬럼 타입과 NULL 허용 여부 검증
    IF NOT EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID('dbo.Characters')
          AND name = 'LastLoginAt'
          AND system_type_id = TYPE_ID('datetime2')
          AND scale = 3
          AND is_nullable = 1
    )
        THROW 50021, N'LastLoginAt 컬럼 구조가 예상과 다릅니다.', 1;

    -- V002 이력이 없을 때만 등록
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.SchemaVersions WITH (UPDLOCK, HOLDLOCK)
        WHERE VersionNumber = 'V002'
    )
    BEGIN
        INSERT INTO dbo.SchemaVersions (
            VersionNumber,
            Description,
            ScriptName
        )
        VALUES (
            'V002',
            N'캐릭터 마지막 접속 시각 컬럼 추가',
            N'V002__add_character_last_login.sql'
        );
    END;

    COMMIT TRAN;
    PRINT N'V002 패치 검증 및 적용 완료';

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
GO
