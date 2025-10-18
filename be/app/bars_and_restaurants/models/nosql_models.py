from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv
import os
import ssl
import certifi

# Load environment variables
load_dotenv()

# Get connection variables from .env
MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB = os.getenv("MONGO_DB")

# Initialize the AsyncIOMotorClient with explicit TLS and CA bundle.
client = AsyncIOMotorClient(
    MONGO_URI,
    server_api=ServerApi('1'),
    tls=True,
    tlsCAFile=certifi.where(),
    tlsDisableOCSPEndpointCheck=True,
    tlsDisableCertificateRevocationCheck=True,
    serverSelectionTimeoutMS=15000,
    connectTimeoutMS=15000,
)
db = client[MONGO_DB]

# Collections
bars_collection = db["bars"]
orders_collection = db["orders"]
reviews_collection = db["reviews"]
menus_collection = db["menus"]

# Sample schema for bars collection in MongoDB
async def insert_bar_into_mongo(bar_id, latitude, longitude, image_url):
    bar_data = {
        "bar_id": bar_id,
        "location": {"type": "Point", "coordinates": [longitude, latitude]},  # Geospatial data
        "image_url": image_url,
    }
    await bars_collection.insert_one(bar_data)

# Ensure geospatial index is created on MongoDB
async def create_geo_index():
    await bars_collection.create_index([("location", "2dsphere")])

# Sample schema for storing menu items in MongoDB
async def insert_menu_into_mongo(menu_id, items):
    menu_data = {
        "menu_id": menu_id,
        "items": items  # List of items with details like price, name, availability, picture, etc.
    }
    await menus_collection.insert_one(menu_data)