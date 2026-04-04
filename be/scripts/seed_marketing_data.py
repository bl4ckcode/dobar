import asyncio
import sys
import os
import random
from datetime import datetime, timedelta

# Add project root to path
sys.path.append(os.getcwd())

from app.database import database
from app.auth.auth_models import User
from app.bars_and_restaurants.models.relational_models import Bar, Promotion, BundlePromotion, Menu, MenuItem, Order
from app.bars_and_restaurants.models.cart_models import OrderItem, OrderStatusHistory
from app.bars_and_restaurants.models.wallet_models import CashbackLedger
from app.advertising.models import AdvertisingCampaign, AdvertisingSubscription
from sqlalchemy import select, insert
from sqlalchemy.sql import func

# Mongo setup
from motor.motor_asyncio import AsyncIOMotorClient
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/barz_db")
MONGO_DB_NAME = os.getenv("MONGO_DB", "barz_db")

# Target Bar IDs and Names (Mock)
TARGET_BARS_DATA = {
    12: "Bar do Carlos",
    13: "Boteco SP",
    14: "Cervejaria Artesanal",
    16: "Vibe Bar",
    17: "Ponto Savassi",
    18: "Porcão BH"
}

async def seed_data():
    print("🚀 Connecting to database...")
    await database.connect()
    
    # Connect to Mongo
    mongo_client = AsyncIOMotorClient(MONGO_URI)
    mongo_db = mongo_client[MONGO_DB_NAME]
    bars_collection = mongo_db["bars"]
    print(f"📦 Connected to MongoDB: {MONGO_DB_NAME}")
    
    try:
        print(f"🎯 Target Bars: {list(TARGET_BARS_DATA.keys())}")
        
        # 0. Ensure Owner and Bars exist
        print("\n🏗️  Seeding Bars (PG + Mongo)...")
        
        # Ensure a default owner
        owner_id = 1
        owner_check = await database.fetch_one("SELECT * FROM bar_owners WHERE id = :id", {"id": owner_id})
        if not owner_check:
             await database.execute(
                 "INSERT INTO bar_owners (id, name, email, phone_number) VALUES (:id, :name, :email, :phone)",
                 {"id": owner_id, "name": "Admin Owner", "email": "admin@barz.com", "phone": "5511999999999"}
             )
             print("   ✅ Created Default Owner (ID 1)")

        for b_id, b_name in TARGET_BARS_DATA.items():
            # Initial Base coordinates (São Paulo Center)
            lat, lon = -23.5505, -46.6333
            
            # Unique Locations to avoid clustering (SP Bars)
            if b_id == 12:   # Bar do Carlos
                lat, lon = -23.5505, -46.6333 # Center
            elif b_id == 13: # Boteco SP
                lat, lon = -23.5520, -46.6350 # Near Paulista
            elif b_id == 14: # Cervejaria Artesanal
                lat, lon = -23.5480, -46.6310 # Near Downtown
            
            # Belo Horizonte Locations (BH Bars)
            elif b_id == 16: # Vibe Bar (BH Center)
                lat, lon = -19.8325619, -43.9798416
            elif b_id == 17: # Ponto Savassi (BH Savassi)
                lat, lon = -19.9395582, -43.9356845
            elif b_id == 18: # Porcão BH (BH Lourdes/Raja)
                lat, lon = -19.954020, -43.956040

            # 1. Postgres Insert (No lat/lon)
            bar_check = await database.fetch_one("SELECT * FROM bars WHERE id = :id", {"id": b_id})
            if not bar_check:
                await database.execute(
                    """
                    INSERT INTO bars (id, owner_id, name, address, phone_number, email, verification_status, country_code)
                    VALUES (:id, :owner_id, :name, :address, :phone, :email, 'verified', 'BR')
                    """,
                    {
                        "id": b_id, 
                        "owner_id": owner_id, 
                        "name": b_name, 
                        "address": "Rua Exemplo, 123", 
                        "phone": "11999999999", 
                        "email": f"contact@{b_id}.com"
                    }
                )
                print(f"   ✅ Created Bar {b_id} ({b_name}) in Postgres")
                
                # Create Default Menu for this bar
                await database.execute(
                     """
                     INSERT INTO menus (bar_id, name, is_active) 
                     VALUES (:bar_id, 'Menu Principal', true)
                     ON CONFLICT DO NOTHING
                     """,
                     {"bar_id": b_id}
                )
            else:
                print(f"   ℹ️  Bar {b_id} exists in Postgres")

            # 2. Mongo Upsert (Location & Logo)
            # Ensure every bar has a valid logo_url to avoid 404s
            # Using existing seed assets as fallback
            logo_url = "https://barz-images.s3.amazonaws.com/seed/pontosavassilogo.jpg"
            
            if b_id == 17:
                logo_url = "https://barz-images.s3.amazonaws.com/seed/pontosavassilogo.jpg"
            elif b_id == 18:
                logo_url = "https://barz-images.s3.amazonaws.com/seed/porcaobhlogo.jpg"
            elif b_id in [12, 13, 14, 16]:
                # Temporary fallback to existing drink images for better visual variety than just one logo
                drink_pics = ["caipirinha.jpeg", "morrito.jpg", "moscowmule.jpeg", "pinacolada.jpeg"]
                pic_index = (b_id % len(drink_pics))
                logo_url = f"https://barz-images.s3.amazonaws.com/seed/{drink_pics[pic_index]}"

            await bars_collection.update_one(
                {"bar_id": b_id},
                {"$set": {
                    "bar_id": b_id,
                    "location": {"type": "Point", "coordinates": [lon, lat]},
                    "image_url": logo_url
                }},
                upsert=True
            )
            print(f"   🌍 Synced Bar {b_id} to MongoDB (Lat: {lat}, Lon: {lon})")

        # 1. Active Promotions
        print("\n✨ Seeding Active Promotions...")
        promos = [
            {
                "bar_id": 16,
                "title": "VIP Cashback 5%",
                "benefit_text": "Ganhe 5% de volta",
                "promotion_type": "cashback",
                "discount_type": "percentage",
                "discount_value": 5.0,
                "is_active": True,  # Using is_active=True directly
                "description": "Cashback exclusivo para clientes VIP"
            },
            {
                "bar_id": 16,
                "title": "Happy Hour Double",
                "benefit_text": "Pague 1 Leve 2",
                "promotion_type": "discount",
                "discount_type": "bogo",
                "discount_value": 0.0,
                "start_time": "18:00",
                "end_time": "20:00",
                "is_active": True,
                "description": "Drinks em dobro das 18h às 20h"
            },
            {
                "bar_id": 12,
                "title": "Boas-vindas",
                "benefit_text": "10% na primeira compra",
                "promotion_type": "discount",
                "discount_type": "percentage",
                "discount_value": 10.0,
                "is_active": True,
                "description": "Desconto especial para novos clientes"
            },
            {
                "bar_id": 13,
                "title": "Quarta do Futebol",
                "benefit_text": "Cerveja com 15% OFF",
                "promotion_type": "discount",
                "discount_type": "percentage",
                "discount_value": 15.0,
                "recurring": True,
                "recurring_days": ["wednesday"],
                "is_active": True,
                "description": "Desconto na cerveja durante os jogos"
            }
        ]
        
        for p in promos:
            # Check if exists
            exists = await database.fetch_one(
                select(Promotion).where(Promotion.bar_id == p["bar_id"], Promotion.title == p["title"])
            )
            if not exists:
                await database.execute(insert(Promotion).values(**p))
                print(f"   ✅ Added promo: {p['title']} (Bar {p['bar_id']})")
            else:
                print(f"   ⚠️  Skipped existing promo: {p['title']} (Bar {p['bar_id']})")

        # 2. Bundle Promotions
        print("\n📦 Seeding Bundle Promotions...")
        bundles = [
            {
                "bar_id": 16,
                "name": "Combo Heineken",
                "description": "Leve 6 Pague 5",
                "bundle_type": "quantity",
                "min_quantity": 6,
                "discount_type": "fixed",
                "discount_value": 15.0, # Approx price of 1 beer
                "is_active": True
            },
            {
                "bar_id": 13,
                "name": "Combo Petisco + Cerveja",
                "description": "Na compra de porção + 2 cervejas, ganhe 10%",
                "bundle_type": "combo",
                "discount_type": "percentage",
                "discount_value": 10.0,
                "is_active": True
            }
        ]
        
        for b in bundles:
            exists = await database.fetch_one(
                select(BundlePromotion).where(BundlePromotion.bar_id == b["bar_id"], BundlePromotion.name == b["name"])
            )
            if not exists:
                await database.execute(insert(BundlePromotion).values(**b))
                print(f"   ✅ Added bundle: {b['name']} (Bar {b['bar_id']})")
            else:
                print(f"   ⚠️  Skipped existing bundle: {b['name']} (Bar {b['bar_id']})")

        # 3. Ad Campaigns (Featured/Search)
        print("\n📢 Seeding Advertising Campaigns...")
        # Ensure subscription exists first
        sub_check = await database.fetch_one(select(AdvertisingSubscription).where(AdvertisingSubscription.bar_id == 16))
        if not sub_check:
             await database.execute(insert(AdvertisingSubscription).values(
                 bar_id=16, 
                 tier="vip", 
                 status="active", 
                 region_code="BR",
                 monthly_fee=199.90,
                 commission_rate=0.10,
                 credits={"banner": 100, "promo_boost": 50}
             ))
             print("   ✅ Created VIP Subscription for Bar 16")
             # Re-fetch id
             sub_check = await database.fetch_one(select(AdvertisingSubscription).where(AdvertisingSubscription.bar_id == 16))

        campaigns = [
            {
                "bar_id": 16,
                "subscription_id": sub_check.id,
                "name": "Destaque Home",
                "campaign_type": "featured",
                "status": "active",
                "budget_type": "credits",
                "budget_amount": 100.00,
                "budget_spent": 0.00,
                "start_time": datetime.utcnow(), 
                "targeting": {},
                "creative": {},
                "impressions": 1500,
                "clicks": 120,
                "conversions": 5
            }
        ]
        for c in campaigns:
            exists = await database.fetch_one(
                select(AdvertisingCampaign).where(AdvertisingCampaign.bar_id == c["bar_id"], AdvertisingCampaign.name == c["name"])
            )
            if not exists:
                await database.execute(insert(AdvertisingCampaign).values(**c))
                print(f"   ✅ Added campaign: {c['name']} (Bar {c['bar_id']})")
            else:
                 print(f"   ⚠️  Skipped existing campaign: {c['name']} (Bar {c['bar_id']})")

        # 4. Trending Drinks (Orders)
        print("\n🔥 Seeding Orders for Trending Drinks...")
        
        # Ensure a Dummy User exists for orders
        user_id = 1
        user_check = await database.fetch_one("SELECT * FROM users WHERE id = :id", {"id": user_id})
        if not user_check:
             # Create a dummy user
             await database.execute(
                 """
                 INSERT INTO users (id, email, phone_number, firebase_uid, is_active)
                 VALUES (:id, 'dummy_user@barz.com', '5511988888888', 'dummy_uid_123', true)
                 """,
                 {"id": user_id}
             )
             print("   ✅ Created Dummy User (ID 1)")

        # Ensure MenuItems exist for Bar 16/13
        classic_drinks = [
            {"name": "Caipirinha", "price": 22.00, "category": "Drinks", "picture": "caipirinha.jpeg"},
            {"name": "Morrito", "price": 28.00, "category": "Drinks", "picture": "morrito.jpg"}, # User calls it Morrito (Mojito)
            {"name": "Moscow Mule", "price": 32.00, "category": "Drinks", "picture": "moscowmule.jpeg"},
            {"name": "Pina Colada", "price": 30.00, "category": "Drinks", "picture": "pinacolada.jpeg"}
        ]

        for b_id in [13, 16, 17, 18]: # Added 17, 18 for BH coverage
            # Get Menu ID
            menu = await database.fetch_one(select(Menu).where(Menu.bar_id == b_id))
            if menu:
                print(f"   Constructor Menu Items for Bar {b_id}...")
                
                # Check & Create Classics
                for drink in classic_drinks:
                    item_check = await database.fetch_one(
                        select(MenuItem).where(MenuItem.menu_id == menu.id, MenuItem.name == drink["name"])
                    )
                    if not item_check:
                         # Construct S3 URL (assuming user will upload to root or seed folder)
                         # Using a public accessible URL structure or signed pattern via backend later
                         # For seeding, we store the KEY or full URL. Apps usually store full URL.
                         img_url = f"https://barz-images.s3.amazonaws.com/seed/{drink['picture']}"
                         
                         await database.execute(insert(MenuItem).values(
                             menu_id=menu.id,
                             name=drink["name"],
                             price=drink["price"],
                             category=drink["category"],
                             picture=img_url,
                             description=f"Clássico {drink['name']} refrescante.",
                             available=True,
                             created_at=datetime.utcnow(),
                             updated_at=datetime.utcnow()
                         ))
                         print(f"      ✅ Created Classic: {drink['name']}")
                    else:
                         # Update picture just in case
                         img_url = f"https://barz-images.s3.amazonaws.com/seed/{drink['picture']}"
                         await database.execute(
                             "UPDATE menu_items SET picture = :pic WHERE id = :id",
                             {"pic": img_url, "id": item_check.id}
                         )

        # Get menu items again (focusing on Classics to boost)
        # We want to boost Classics to be "Most Wanted"
        classic_names = [d["name"] for d in classic_drinks]
        query = select(MenuItem).join(Menu).where(
            Menu.bar_id.in_([16, 17]), # Focus on BH bars
            MenuItem.name.in_(classic_names)
        )
        items = await database.fetch_all(query)
        
        if items:
            print(f"   Found {len(items)} classic items. Generating TRENDING orders...")
            
            for item in items:
                # Create 30-50 orders to ensure High Trending Score
                count = random.randint(30, 50)
                print(f"   🌟 Boosting '{item.name}' (Bar {item.menu_id}) with {count} orders")
                
                for _ in range(count):
                    user_id = 1 
                    
                    # Create Order
                    # ... (rest of order creation)
                    order_data = {
                        "user_id": user_id,
                        "bar_id": item.menu_id, # Actually incorrect field usage in previous logic safely ignored?
                                                # Menu.bar_id is what we need. 
                                                # item.menu_id is the ID of the menu.
                                                # We need bar_id. Join gave us MenuItem.
                        "status": "completed",
                        "total_price": item.price,
                        "location_identifier": "table_1",
                        "created_at": datetime.utcnow() - timedelta(days=random.randint(0, 6))
                    }
                    
                    # Fix bar_id lookup
                    menu_row = await database.fetch_one(select(Menu).where(Menu.id == item.menu_id))
                    order_data["bar_id"] = menu_row.bar_id

                    order_id = await database.execute(insert(Order).values(**order_data))
                    
                    # Create Order Item
                    item_data = {
                        "order_id": order_id,
                        "menu_item_id": item.id,
                        "menu_item_name": item.name,
                        "unit_price": item.price,
                        "quantity": 1,
                        "total_price": item.price,
                        "created_at": order_data["created_at"] # SYNC created_at with Order
                    }
                    await database.execute(insert(OrderItem).values(**item_data))
                    
        else:
             print("   ⚠️  No menu items found. Skipping trending generation.")

        # 5. Location Config
        print("\n📍 Setting Location Config...")
        from sqlalchemy import update
        await database.execute(
            update(Bar).where(Bar.id == 16).values(
                location_method="spot_list",
                location_spots=[
                    {"id": "vip_1", "name": "Camarote 1"},
                    {"id": "vip_2", "name": "Camarote 2"},
                    {"id": "pool", "name": "Bar da Piscina"}
                ]
            )
        )
        print("   ✅ Updated Bar 16 location config to 'spot_list'")

    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        await database.disconnect()
        print("\n👋 Done!")

if __name__ == "__main__":
    asyncio.run(seed_data())
