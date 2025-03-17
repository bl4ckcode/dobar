from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from databases import Database
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# PostgreSQL connection URL
DATABASE_URL = f"postgresql://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@{os.getenv('POSTGRES_HOST')}:{os.getenv('POSTGRES_PORT')}/{os.getenv('POSTGRES_DB')}"

# Initialize the database connection
database = Database(DATABASE_URL)
engine = create_engine(DATABASE_URL)
metadata = MetaData()

# Base class for models
Base = declarative_base()