from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from databases import Database
import os

# Fetch the database URL from environment variables for flexibility
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")

# If using PostgreSQL or MySQL, it might look something like this:
# DATABASE_URL = "postgresql://user:password@localhost/dbname"
# DATABASE_URL = "mysql+pymysql://user:password@localhost/dbname"

# Initialize the database connection
database = Database(DATABASE_URL)
engine = create_engine(DATABASE_URL)
metadata = MetaData()

# Base class for models
Base = declarative_base()