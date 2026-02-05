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

# Target Bar IDs and Names (Mock)
TARGET_BARS_DATA = {
    12: "Bar do Carlos",
    13: "Boteco SP",
    14: "Cervejaria Artesanal",
    16: "Vibe Bar",
    17: "Night Club",
    18: "Lounge 18"
}

async def seed_data():
    print("🚀 Connecting to database...")
    await database.connect()
    
    try:
        print(f"🎯 Target Bars: {list(TARGET_BARS_DATA.keys())}")
        
        # 0. Ensure Owner and Bars exist
        print("\n🏗️  Seeding Bars...")
        
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
            bar_check = await database.fetch_one("SELECT * FROM bars WHERE id = :id", {"id": b_id})
            if not bar_check:
                # Default coordinates (SP)
                lat, lon = -23.5505, -46.6333
                
                # Mock Location for Bar 16 (Belo Horizonte - User Location)
                if b_id == 16:
                    lat, lon = -19.8325619, -43.9798416
                # Mock Location for Bar 17 (BH - Savassi)
                elif b_id == 17:
                    lat, lon = -19.9395582, -43.9356845

                await database.execute(
                    """
                    INSERT INTO bars (id, owner_id, name, address, phone_number, email, verification_status, country_code, latitude, longitude)
                    VALUES (:id, :owner_id, :name, :address, :phone, :email, 'verified', 'BR', :lat, :lon)
                    """,
                    {
                        "id": b_id, 
                        "owner_id": owner_id, 
                        "name": b_name, 
                        "address": "Rua Exemplo, 123", 
                        "phone": "11999999999", 
                        "email": f"contact@{b_id}.com",
                        "lat": lat,
                        "lon": lon
                    }
                )
                print(f"   ✅ Created Bar {b_id} ({b_name})")
                
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
                # Update location for Bar 16 if it exists (force move to User)
                if b_id == 16:
                     await database.execute(
                        "UPDATE bars SET latitude = :lat, longitude = :lon WHERE id = :id",
                        {"id": b_id, "lat": -19.8325619, "lon": -43.9798416}
                     )
                     print(f"   📍 Moved Bar 16 to BH User Location")
                print(f"   ℹ️  Bar {b_id} exists")

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
        for b_id in [13, 16]:
            # Get Menu ID
            menu = await database.fetch_one(select(Menu).where(Menu.bar_id == b_id))
            if menu:
                # Check for items
                items_check = await database.fetch_all(select(MenuItem).where(MenuItem.menu_id == menu.id))
                if not items_check:
                    print(f"   Constructor Menu Items for Bar {b_id}...")
                    mock_items = [
                        {"menu_id": menu.id, "name": "Chopp Brahma", "price": 12.00, "category": "Cervejas"},
                        {"menu_id": menu.id, "name": "Caipirinha", "price": 25.00, "category": "Drinks"},
                        {"menu_id": menu.id, "name": "Porção Fritas", "price": 30.00, "category": "Petiscos"}
                    ]
                    for it in mock_items:
                        await database.execute(insert(MenuItem).values(**it))
                    print(f"   ✅ Created 3 MenuItems for Bar {b_id}")

        # Get menu items again
        query = select(MenuItem).join(Menu).where(Menu.bar_id.in_([16, 13]), Menu.is_active == True)
        items = await database.fetch_all(query)
        
        if items:
            print(f"   Found {len(items)} menu items. Generating orders...")
            
            # Pick a few "popular" items
            popular_items = random.sample(items, min(len(items), 3))
            
            for item in popular_items:
                # Create 10-20 orders for this item
                count = random.randint(10, 20)
                print(f"   🌟 Boosting '{item.name}' with {count} orders")
                
                for _ in range(count):
                    user_id = 1 
                    
                    # Create Order
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
                        "total_price": item.price
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
