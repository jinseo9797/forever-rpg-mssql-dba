from fastapi import FastAPI, HTTPException
import pyodbc

from db import db_cursor, rows_as_dict

app = FastAPI(title="Forever RPG API", version="0.1.0")


@app.get("/health")
def health():
    try:
        with db_cursor() as cursor:
            cursor.execute("SELECT DB_NAME() AS database_name, 1 AS ok")
            return rows_as_dict(cursor)[0]
    except (pyodbc.Error, RuntimeError):
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
        raise HTTPException(status_code=503, detail="아이템 조회 실패")
