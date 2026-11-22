import logging
import re
from pathlib import Path

import pyodbc
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from db import db_cursor, rows_as_dict

app = FastAPI(title="Forever RPG API", version="0.4.0")
logger = logging.getLogger(__name__)


@app.get("/", include_in_schema=False)
def game_screen():
    # FastAPI와 같은 출처에서 게임 화면 제공
    return FileResponse(Path(__file__).resolve().parent / "index.html")

# 구매 SP에서 명시적으로 발생시키는 비즈니스 오류
PURCHASE_ERRORS = {
    50001: (400, "구매 수량은 1 이상이어야 합니다."),
    50002: (404, "존재하지 않는 캐릭터입니다."),
    50003: (400, "구매할 수 없는 아이템입니다."),
    50004: (400, "보유 골드가 부족합니다."),
    50005: (409, "골드 차감에 실패했습니다."),
    50006: (409, "인벤토리 수량 변경에 실패했습니다."),
}


class PurchaseRequest(BaseModel):
    character_id: int = Field(gt=0)
    item_id: int = Field(gt=0)
    quantity: int = Field(default=1, gt=0, le=1000)


def purchase_error(exc: pyodbc.Error) -> HTTPException:
    # SQL Server가 전달한 프로시저 THROW 번호만 허용 목록에서 추출
    detail = "아이템 구매 처리 중 데이터베이스 오류가 발생했습니다."
    text = " ".join(str(part) for part in exc.args)
    for number, (status, message) in PURCHASE_ERRORS.items():
        if re.search(rf"\({number}\)", text):
            return HTTPException(status_code=status, detail=message)

    logger.exception("구매 SQL 처리 실패")
    return HTTPException(status_code=503, detail=detail)


@app.get("/health")
def health():
    try:
        with db_cursor() as cursor:
            cursor.execute("SELECT DB_NAME() AS database_name, 1 AS ok")
            return rows_as_dict(cursor)[0]
    except (pyodbc.Error, RuntimeError):
        logger.exception("DB 연결 확인 실패")
        raise HTTPException(status_code=503, detail="데이터베이스 연결 실패")


@app.get("/characters/{character_id}")
def get_character(character_id: int):
    if character_id <= 0:
        raise HTTPException(status_code=400, detail="유효하지 않은 캐릭터 ID")
    try:
        with db_cursor() as cursor:
            cursor.execute("EXEC dbo.usp_GetCharacter @CharacterId=?", character_id)
            characters = rows_as_dict(cursor)
    except (pyodbc.Error, RuntimeError):
        logger.exception("캐릭터 조회 실패")
        raise HTTPException(status_code=503, detail="캐릭터 조회 실패")
    if not characters:
        raise HTTPException(status_code=404, detail="캐릭터가 없습니다")
    return characters[0]


@app.get("/items")
def list_items():
    try:
        with db_cursor() as cursor:
            cursor.execute(
                "SELECT ItemId, ItemName, ItemType, Price, IsAvailable "
                "FROM dbo.Items WHERE IsAvailable=1 ORDER BY ItemId"
            )
            return rows_as_dict(cursor)
    except (pyodbc.Error, RuntimeError):
        logger.exception("아이템 목록 조회 실패")
        raise HTTPException(status_code=503, detail="아이템 조회 실패")


@app.get("/characters/{character_id}/inventory")
def get_inventory(character_id: int):
    if character_id <= 0:
        raise HTTPException(status_code=400, detail="유효하지 않은 캐릭터 ID")
    try:
        with db_cursor() as cursor:
            cursor.execute(
                "SELECT i.InventoryId, i.CharacterId, i.ItemId, "
                "t.ItemName, t.ItemType, i.Quantity "
                "FROM dbo.Inventory AS i "
                "JOIN dbo.Items AS t ON t.ItemId = i.ItemId "
                "WHERE i.CharacterId = ? ORDER BY i.ItemId",
                character_id,
            )
            return rows_as_dict(cursor)
    except (pyodbc.Error, RuntimeError):
        logger.exception("인벤토리 조회 실패")
        raise HTTPException(status_code=503, detail="인벤토리 조회 실패")


@app.post("/purchase")
def purchase_item(request: PurchaseRequest):
    # 게임 서버는 구매 비즈니스 로직을 재구현하지 않고 SP만 호출
    try:
        with db_cursor() as cursor:
            cursor.execute(
                "EXEC dbo.usp_PurchaseItem @CharacterId=?, @ItemId=?, @Quantity=?",
                request.character_id,
                request.item_id,
                request.quantity,
            )
            result = rows_as_dict(cursor)
    except pyodbc.Error as exc:
        raise purchase_error(exc) from exc
    except RuntimeError:
        logger.exception("DB 연결 설정 오류")
        raise HTTPException(status_code=503, detail="데이터베이스 연결 실패")

    if not result:
        raise HTTPException(status_code=503, detail="구매 결과를 반환받지 못했습니다.")
    return result[0]


# 사냥 SP에서 반환하는 오류
HUNT_ERRORS = {
    50101: (400, "캐릭터와 몬스터 ID를 확인해 주세요."),
    50102: (404, "존재하지 않는 캐릭터입니다."),
    50103: (400, "사냥할 수 없는 몬스터입니다."),
    50104: (409, "몬스터 보상 설정 오류입니다."),
    50105: (409, "보유 골드 최대치를 초과합니다."),
    50106: (409, "골드 지급에 실패했습니다."),
}


class HuntRequest(BaseModel):
    character_id: int = Field(gt=0)
    monster_id: int = Field(gt=0)


@app.get("/monsters")
def list_monsters():
    try:
        with db_cursor() as cursor:
            cursor.execute(
                "SELECT MonsterId, MonsterName, MonsterLevel, MaxHP, RewardGold "
                "FROM dbo.Monsters WHERE IsActive = 1 ORDER BY MonsterId"
            )
            return rows_as_dict(cursor)
    except (pyodbc.Error, RuntimeError):
        logger.exception("몬스터 목록 조회 실패")
        raise HTTPException(status_code=503, detail="몬스터 목록 조회 실패")


@app.get("/characters/{character_id}/hunts")
def get_recent_hunts(character_id: int):
    if character_id <= 0:
        raise HTTPException(status_code=400, detail="유효하지 않은 캐릭터 ID")
    try:
        with db_cursor() as cursor:
            # Day 3 인덱스의 CharacterId + HuntedAt 순서를 이용하는 조회 패턴
            cursor.execute(
                "SELECT TOP (20) h.HuntId, h.MonsterId, m.MonsterName, "
                "h.EarnedGold, h.HuntedAt "
                "FROM dbo.HuntHistory AS h "
                "JOIN dbo.Monsters AS m ON m.MonsterId = h.MonsterId "
                "WHERE h.CharacterId = ? "
                "ORDER BY h.HuntedAt DESC, h.HuntId DESC",
                character_id,
            )
            return rows_as_dict(cursor)
    except (pyodbc.Error, RuntimeError):
        logger.exception("사냥 이력 조회 실패")
        raise HTTPException(status_code=503, detail="사냥 기록 조회 실패")



class StartBattleRequest(BaseModel):
    character_id: int = Field(gt=0)
    monster_id: int = Field(gt=0)


class AttackBattleRequest(BaseModel):
    character_id: int = Field(gt=0)
    battle_id: int = Field(gt=0)


def battle_error(exc: pyodbc.Error):
    text = " ".join(str(part) for part in exc.args)
    errors = {
        50201: (404, "존재하지 않는 캐릭터입니다."),
        50202: (400, "사냥할 수 없는 몬스터입니다."),
        50203: (404, "존재하지 않는 전투입니다."),
        50204: (409, "이미 종료된 전투입니다."),
        50105: (409, "보유 골드 최대치를 초과합니다."),
        50108: (409, "전투 보상을 지급할 수 없습니다."),
    }
    for number, (status, detail) in errors.items():
        if re.search(rf"\\({number}\\)", text):
            return HTTPException(status_code=status, detail=detail)
    logger.exception("전투 처리 DB 오류")
    return HTTPException(status_code=503, detail="전투 처리 중 오류가 발생했습니다.")


@app.get("/characters/{character_id}/battle")
def get_active_battle(character_id: int):
    if character_id <= 0:
        raise HTTPException(status_code=400, detail="유효하지 않은 캐릭터 ID")
    try:
        with db_cursor() as cursor:
            cursor.execute(
                "SELECT b.BattleId,b.CharacterId,b.MonsterId,m.MonsterName,"
                "b.PlayerHP,b.MonsterHP,b.TurnCount,b.Status,b.RewardClaimed,m.RewardGold "
                "FROM dbo.BattleEncounters b JOIN dbo.Monsters m ON m.MonsterId=b.MonsterId "
                "WHERE b.CharacterId=? AND b.Status='Active'",
                character_id,
            )
            rows = rows_as_dict(cursor)
            return rows[0] if rows else None
    except (pyodbc.Error, RuntimeError):
        logger.exception("전투 조회 실패")
        raise HTTPException(status_code=503, detail="전투 정보를 조회하지 못했습니다. V003 패치를 확인하세요.")


@app.post("/battle/start")
def start_battle(request: StartBattleRequest):
    try:
        with db_cursor() as cursor:
            cursor.execute(
                "EXEC dbo.usp_StartBattle @CharacterId=?, @MonsterId=?",
                request.character_id, request.monster_id,
            )
            battle_id = int(rows_as_dict(cursor)[0]["BattleId"])
        return get_active_battle(request.character_id)
    except pyodbc.Error as exc:
        raise battle_error(exc) from exc
    except RuntimeError:
        logger.exception("전투 DB 연결 실패")
        raise HTTPException(status_code=503, detail="DB 연결 실패")


@app.post("/battle/attack")
def attack_battle(request: AttackBattleRequest):
    try:
        with db_cursor() as cursor:
            cursor.execute(
                "EXEC dbo.usp_AttackBattle @CharacterId=?, @BattleId=?",
                request.character_id, request.battle_id,
            )
            result = rows_as_dict(cursor)
        if not result:
            raise HTTPException(status_code=503, detail="전투 결과가 없습니다.")
        return result[0]
    except pyodbc.Error as exc:
        raise battle_error(exc) from exc
    except RuntimeError:
        logger.exception("전투 DB 연결 실패")
        raise HTTPException(status_code=503, detail="DB 연결 실패")
