from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from databases import Database
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

# Initialize the database connection
database = Database(DATABASE_URL, min_size=1, max_size=5, ssl=False)
print("🐛 DATABASE_URL =", DATABASE_URL)

engine = create_engine(DATABASE_URL)
metadata = MetaData()

# Base class for models
Base = declarative_base()

# Session factory for synchronous operations
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()