from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# MongoDB connection
client = AsyncIOMotorClient(f"mongodb://{os.getenv('MONGO_HOST')}:{os.getenv('MONGO_PORT')}/")
db = client[os.getenv("MONGO_DB")]

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