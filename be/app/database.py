from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
from databases import Database
from dotenv import load_dotenv
import os

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
DATABASE_REPLICA_URL = os.getenv("DATABASE_REPLICA_URL", DATABASE_URL)
IS_PRODUCTION = os.getenv("FLY_APP_NAME") is not None

POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "10"))
MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "20"))
POOL_RECYCLE = int(os.getenv("DB_POOL_RECYCLE", "300"))

database = Database(
    DATABASE_URL,
    min_size=2 if IS_PRODUCTION else 1,
    max_size=POOL_SIZE,
    ssl=False
)

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=POOL_SIZE,
    max_overflow=MAX_OVERFLOW,
    pool_pre_ping=True,
    pool_recycle=POOL_RECYCLE,
    pool_timeout=30,
    echo=False,
)

replica_engine = create_engine(
    DATABASE_REPLICA_URL,
    poolclass=QueuePool,
    pool_size=POOL_SIZE // 2,
    max_overflow=MAX_OVERFLOW // 2,
    pool_pre_ping=True,
    pool_recycle=POOL_RECYCLE,
    pool_timeout=30,
    echo=False,
)

metadata = MetaData()
Base = declarative_base()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
ReplicaSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=replica_engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_read_db():
    db = ReplicaSessionLocal()
    try:
        yield db
    finally:
        db.close()