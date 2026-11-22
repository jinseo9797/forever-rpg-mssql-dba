import os
from contextlib import contextmanager

import pyodbc
from dotenv import load_dotenv

load_dotenv()


def connect():
    driver = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
    server = os.getenv("DB_SERVER", "localhost")
    database = os.getenv("DB_NAME", "ForeverRPG")
    trusted = os.getenv("DB_TRUSTED_CONNECTION", "yes")
    trust_cert = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes")

    parts = [
        f"DRIVER={{{driver}}}",
        f"SERVER={server}",
        f"DATABASE={database}",
        f"TrustServerCertificate={trust_cert}",
        "Connection Timeout=5",
    ]
    if trusted.lower() == "yes":
        parts.append("Trusted_Connection=yes")
    else:
        username = os.getenv("DB_USER")
        password = os.getenv("DB_PASSWORD")
        if not username or not password:
            raise RuntimeError("DB_USER와 DB_PASSWORD를 설정해 주세요.")
        parts.extend([f"UID={username}", f"PWD={password}"])

    # 저장 프로시저가 자체 트랜잭션을 관리하므로 자동 커밋 사용
    return pyodbc.connect(";".join(parts), autocommit=True)


@contextmanager
def db_cursor():
    connection = connect()
    try:
        cursor = connection.cursor()
        try:
            yield cursor
        finally:
            cursor.close()
    finally:
        connection.close()


def rows_as_dict(cursor):
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]
