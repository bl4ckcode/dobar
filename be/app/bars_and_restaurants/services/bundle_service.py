from datetime import datetime
from typing import List, Optional
from app.database import database
from app.bars_and_restaurants.models.relational_models import BundlePromotion as BundleModel


async def get_active_bundles_for_bar(bar_id: int) -> List[dict]:
    now = datetime.utcnow()
    current_time = now.strftime("%H:%M")
    current_day = now.strftime("%A").lower()
    
    query = BundleModel.__table__.select().where(
        BundleModel.bar_id == bar_id,
        BundleModel.is_active == True
    )
    bundles = await database.fetch_all(query)
    
    active_bundles = []
    for bundle in bundles:
        bundle_dict = dict(bundle)
        
        if bundle_dict.get("start_date") and bundle_dict["start_date"] > now:
            continue
        if bundle_dict.get("end_date") and bundle_dict["end_date"] < now:
            continue
            
        if bundle_dict.get("recurring_days"):
            if current_day not in bundle_dict["recurring_days"]:
                continue
                
        if bundle_dict.get("start_time") and bundle_dict.get("end_time"):
            if not (bundle_dict["start_time"] <= current_time <= bundle_dict["end_time"]):
                continue
        
        active_bundles.append(bundle_dict)
    
    return active_bundles


def calculate_bundles_for_cart(items: List[dict], bundles: List[dict]) -> dict:
    applied_bundles = []
    total_savings = 0.0
    bundle_hint = None
    
    items_by_bar = {}
    for item in items:
        bar_id = item["bar_id"]
        if bar_id not in items_by_bar:
            items_by_bar[bar_id] = []
        items_by_bar[bar_id].append(item)
    
    for bar_id, bar_items in items_by_bar.items():
        bar_bundles = [b for b in bundles if b["bar_id"] == bar_id]
        
        for bundle in bar_bundles:
            result = apply_bundle(bar_items, bundle)
            if result["applied"]:
                applied_bundles.append({
                    "bundle_id": bundle["id"],
                    "bundle_name": bundle["name"],
                    "discount_amount": result["discount"],
                    "message": result["message"]
                })
                total_savings += result["discount"]
            elif result.get("hint"):
                if not bundle_hint:
                    bundle_hint = result["hint"]
    
    return {
        "applied_bundles": applied_bundles,
        "bundle_savings": total_savings,
        "bundle_hint": bundle_hint
    }


def apply_bundle(items: List[dict], bundle: dict) -> dict:
    bundle_type = bundle["bundle_type"]
    min_quantity = bundle.get("min_quantity", 2)
    discount_type = bundle["discount_type"]
    discount_value = bundle["discount_value"]
    
    if bundle_type == "quantity":
        return apply_quantity_bundle(items, bundle, min_quantity, discount_type, discount_value)
    elif bundle_type == "category":
        return apply_category_bundle(items, bundle, min_quantity, discount_type, discount_value)
    elif bundle_type == "combo":
        return apply_combo_bundle(items, bundle, discount_type, discount_value)
    
    return {"applied": False}


def apply_quantity_bundle(items: List[dict], bundle: dict, min_qty: int, disc_type: str, disc_value: float) -> dict:
    target_items = bundle.get("target_items") or []
    
    for item in items:
        if target_items and item["menu_item_id"] not in target_items:
            continue
            
        if item["quantity"] >= min_qty:
            item_total = item["quantity"] * item["unit_price"]
            discount = calculate_discount(item_total, disc_type, disc_value)
            return {
                "applied": True,
                "discount": discount,
                "message": f"⚡ {bundle['name']}: -R$ {discount:.2f}"
            }
        elif item["quantity"] == min_qty - 1:
            return {
                "applied": False,
                "hint": f"🔥 Add 1 more {item['menu_item_name']} to save with {bundle['name']}!"
            }
    
    return {"applied": False}


def apply_category_bundle(items: List[dict], bundle: dict, min_qty: int, disc_type: str, disc_value: float) -> dict:
    target_category = bundle.get("target_category")
    if not target_category:
        return {"applied": False}
    
    category_total = 0.0
    category_qty = 0
    
    for item in items:
        category_total += item["quantity"] * item["unit_price"]
        category_qty += item["quantity"]
    
    if category_qty >= min_qty:
        discount = calculate_discount(category_total, disc_type, disc_value)
        return {
            "applied": True,
            "discount": discount,
            "message": f"⚡ {bundle['name']}: -R$ {discount:.2f}"
        }
    elif category_qty == min_qty - 1:
        return {
            "applied": False,
            "hint": f"🔥 Add 1 more item to get {bundle['name']}!"
        }
    
    return {"applied": False}


def apply_combo_bundle(items: List[dict], bundle: dict, disc_type: str, disc_value: float) -> dict:
    target_items = bundle.get("target_items") or []
    if not target_items:
        return {"applied": False}
    
    item_ids_in_cart = {item["menu_item_id"] for item in items}
    
    if all(tid in item_ids_in_cart for tid in target_items):
        combo_total = sum(
            item["quantity"] * item["unit_price"]
            for item in items
            if item["menu_item_id"] in target_items
        )
        discount = calculate_discount(combo_total, disc_type, disc_value)
        return {
            "applied": True,
            "discount": discount,
            "message": f"⚡ {bundle['name']}: -R$ {discount:.2f}"
        }
    
    missing = set(target_items) - item_ids_in_cart
    if len(missing) == 1:
        return {
            "applied": False,
            "hint": f"🔥 Add 1 more item to complete the {bundle['name']} combo!"
        }
    
    return {"applied": False}


def calculate_discount(total: float, disc_type: str, disc_value: float) -> float:
    if disc_type == "percentage":
        return round(total * (disc_value / 100), 2)
    elif disc_type == "fixed":
        return min(disc_value, total)
    return 0.0
