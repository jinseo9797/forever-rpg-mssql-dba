
/*
    Project  : Forever RPG
    Database : ForeverRPG
    Version  : V001
    Purpose  : Initial Database Schema
    DBMS     : Microsoft SQL Server

    Tables:
      01. Characters
      02. Items
      03. Monsters
      04. Inventory
      05. PurchaseHistory
      06. HuntHistory
      07. SchemaVersions
*/

USE ForeverRPG;
GO

-- =====================================================
-- 01. Characters
-- 캐릭터 기본 정보 및 보유 골드 관리
-- =====================================================

CREATE TABLE dbo.Characters (
    CharacterId INT IDENTITY(1,1) PRIMARY KEY,
    CharacterName NVARCHAR(50) NOT NULL UNIQUE,
    ClassName NVARCHAR(30) NOT NULL,
    CharacterLevel INT NOT NULL DEFAULT 1,
    Gold INT NOT NULL DEFAULT 1000,
    CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    -- 캐릭터 레벨은 1 이상
    CONSTRAINT CK_Characters_Level
        CHECK (CharacterLevel >= 1),

    -- 보유 골드는 0 이상
    CONSTRAINT CK_Characters_Gold
        CHECK (Gold >= 0)
);
GO

-- =====================================================
-- 02. Items
-- 아이템 정보 및 상점 판매 가격 관리
-- =====================================================

CREATE TABLE dbo.Items (
    ItemId INT IDENTITY(1,1) PRIMARY KEY,
    ItemName NVARCHAR(100) NOT NULL,
    ItemType NVARCHAR(30) NOT NULL,
    Price INT NOT NULL,
    IsAvailable BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    -- 아이템 가격은 0 이상
    CONSTRAINT CK_Items_Price
        CHECK (Price >= 0)
);
GO

-- =====================================================
-- 03. Monsters
-- 몬스터 정보 및 사냥 보상 관리
-- =====================================================

CREATE TABLE dbo.Monsters (
    MonsterId INT IDENTITY(1,1) PRIMARY KEY,
    MonsterName NVARCHAR(100) NOT NULL,
    MonsterLevel INT NOT NULL DEFAULT 1,
    MaxHP INT NOT NULL,
    RewardGold INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    -- 몬스터 레벨은 1 이상
    CONSTRAINT CK_Monsters_Level
        CHECK (MonsterLevel >= 1),

    -- 몬스터 최대 체력은 1 이상
    CONSTRAINT CK_Monsters_MaxHP
        CHECK (MaxHP >= 1),

    -- 사냥 보상 골드는 0 이상
    CONSTRAINT CK_Monsters_RewardGold
        CHECK (RewardGold >= 0)
);
GO

-- =====================================================
-- 04. Inventory
-- 캐릭터별 보유 아이템 및 수량 관리
-- =====================================================

CREATE TABLE dbo.Inventory (
    InventoryId INT IDENTITY(1,1) PRIMARY KEY,
    CharacterId INT NOT NULL,
    ItemId INT NOT NULL,
    Quantity INT NOT NULL DEFAULT 1,
    UpdatedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    -- 캐릭터 참조
    CONSTRAINT FK_Inventory_Characters
        FOREIGN KEY (CharacterId)
        REFERENCES dbo.Characters(CharacterId),

    -- 아이템 참조
    CONSTRAINT FK_Inventory_Items
        FOREIGN KEY (ItemId)
        REFERENCES dbo.Items(ItemId),

    -- 동일한 캐릭터와 아이템의 중복 등록 방지
    CONSTRAINT UQ_Inventory_Character_Item
        UNIQUE (CharacterId, ItemId),

    -- 아이템 보유 수량은 1 이상
    CONSTRAINT CK_Inventory_Quantity
        CHECK (Quantity >= 1)
);
GO

-- =====================================================
-- 05. PurchaseHistory
-- 캐릭터별 아이템 구매 이력 관리
-- =====================================================

CREATE TABLE dbo.PurchaseHistory (
    PurchaseId BIGINT IDENTITY(1,1) PRIMARY KEY,
    CharacterId INT NOT NULL,
    ItemId INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice INT NOT NULL,
    TotalPrice BIGINT NOT NULL,
    PurchasedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    -- 구매 캐릭터 참조
    CONSTRAINT FK_PurchaseHistory_Characters
        FOREIGN KEY (CharacterId)
        REFERENCES dbo.Characters(CharacterId),

    -- 구매 아이템 참조
    CONSTRAINT FK_PurchaseHistory_Items
        FOREIGN KEY (ItemId)
        REFERENCES dbo.Items(ItemId),

    -- 구매 수량은 1 이상
    CONSTRAINT CK_PurchaseHistory_Quantity
        CHECK (Quantity >= 1),

    -- 구매 당시 단가는 0 이상
    CONSTRAINT CK_PurchaseHistory_UnitPrice
        CHECK (UnitPrice >= 0),

    -- 총 구매 금액의 정합성 검증
    CONSTRAINT CK_PurchaseHistory_TotalPrice
        CHECK (
            TotalPrice = CAST(UnitPrice AS BIGINT) * Quantity
        )
);
GO

-- =====================================================
-- 06. HuntHistory
-- 캐릭터별 몬스터 사냥 및 보상 지급 이력
-- =====================================================

CREATE TABLE dbo.HuntHistory (
    HuntId BIGINT IDENTITY(1,1) PRIMARY KEY,
    CharacterId INT NOT NULL,
    MonsterId INT NOT NULL,
    EarnedGold INT NOT NULL,
    HuntedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    -- 사냥 캐릭터 참조
    CONSTRAINT FK_HuntHistory_Characters
        FOREIGN KEY (CharacterId)
        REFERENCES dbo.Characters(CharacterId),

    -- 사냥 몬스터 참조
    CONSTRAINT FK_HuntHistory_Monsters
        FOREIGN KEY (MonsterId)
        REFERENCES dbo.Monsters(MonsterId),

    -- 사냥 보상 골드는 0 이상
    CONSTRAINT CK_HuntHistory_EarnedGold
        CHECK (EarnedGold >= 0)
);
GO

-- =====================================================
-- 07. SchemaVersions
-- 데이터베이스 변경 및 패치 버전 이력 관리
-- =====================================================

CREATE TABLE dbo.SchemaVersions (
    VersionId INT IDENTITY(1,1) PRIMARY KEY,
    VersionNumber VARCHAR(20) NOT NULL,
    Description NVARCHAR(200) NOT NULL,
    ScriptName NVARCHAR(200) NOT NULL,
    AppliedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
    AppliedBy NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),

    -- 동일한 패치 버전 중복 기록 방지
    CONSTRAINT UQ_SchemaVersions_Version
        UNIQUE (VersionNumber)
);
GO

-- =====================================================
-- 08. Initial Schema Version
-- 초기 스키마 적용 이력 등록
-- =====================================================

INSERT INTO dbo.SchemaVersions (
    VersionNumber,
    Description,
    ScriptName
)
VALUES (
    'V001',
    N'Forever RPG 초기 데이터베이스 테이블 생성',
    N'V001__init_schema.sql'
);
GO
