from datetime import datetime
from typing import List, Dict, Any, Optional
from app.database import database
from ..models.relational_models import Order, Bar


CONFLICT_TYPES = {
    "already_cancelled": "Order was already cancelled",
    "already_completed": "Order was already completed",
    "price_changed": "Item price has changed since order was queued",
    "item_unavailable": "Item is no longer available",
    "bar_closed": "Bar is currently closed"
}


async def check_order_conflict(order_id: int, operation_type: str, client_timestamp: str) -> Optional[Dict[str, Any]]:
    query = Order.__table__.select().where(Order.id == order_id)
    db_order = await database.fetch_one(query)
    
    if not db_order:
        return {
            "conflict_type": "order_not_found",
            "server_state": None,
            "resolution": "Order no longer exists"
        }
    
    order_dict = dict(db_order)
    
    if operation_type == "cancel_order":
        if order_dict["status"] == "cancelled":
            return {
                "conflict_type": "already_cancelled",
                "server_state": {
                    "status": order_dict["status"],
                    "updated_at": order_dict["updated_at"].isoformat() if order_dict["updated_at"] else None
                },
                "resolution": CONFLICT_TYPES["already_cancelled"]
            }
        
        if order_dict["status"] == "completed":
            return {
                "conflict_type": "already_completed",
                "server_state": {
                    "status": order_dict["status"],
                    "completed_at": order_dict["completed_at"].isoformat() if order_dict["completed_at"] else None
                },
                "resolution": CONFLICT_TYPES["already_completed"]
            }
        
        if order_dict["status"] not in ["pending", "confirmed"]:
            return {
                "conflict_type": "cannot_cancel",
                "server_state": {"status": order_dict["status"]},
                "resolution": "Cannot cancel order in status: " + order_dict["status"]
            }
    
    return None


async def check_bar_status(bar_id: int) -> Optional[Dict[str, Any]]:
    query = Bar.__table__.select().where(Bar.id == bar_id)
    db_bar = await database.fetch_one(query)
    
    if not db_bar:
        return {
            "conflict_type": "bar_not_found",
            "server_state": None,
            "resolution": "Bar no longer exists"
        }
    
    bar_dict = dict(db_bar)
    
    if bar_dict.get("status") == "closed":
        return {
            "conflict_type": "bar_closed",
            "server_state": {"status": "closed"},
            "resolution": CONFLICT_TYPES["bar_closed"]
        }
    
    return None


async def sync_operations(user_id: int, operations: List[Dict[str, Any]]) -> Dict[str, Any]:
    synced = []
    conflicts = []
    
    for op in operations:
        op_type = op.get("type")
        
        if op_type == "cancel_order":
            order_id = op.get("order_id")
            client_timestamp = op.get("client_timestamp")
            
            conflict = await check_order_conflict(order_id, op_type, client_timestamp)
            
            if conflict:
                conflicts.append({
                    "operation": op,
                    "conflict_type": conflict["conflict_type"],
                    "server_state": conflict["server_state"],
                    "resolution": conflict["resolution"]
                })
            else:
                synced.append({
                    "operation": op,
                    "result": "pending_execution"
                })
        
        elif op_type == "create_order":
            bar_id = op.get("bar_id")
            bar_conflict = await check_bar_status(bar_id)
            
            if bar_conflict:
                conflicts.append({
                    "operation": op,
                    "conflict_type": bar_conflict["conflict_type"],
                    "server_state": bar_conflict["server_state"],
                    "resolution": bar_conflict["resolution"]
                })
            else:
                synced.append({
                    "operation": op,
                    "result": "pending_execution"
                })
        
        else:
            synced.append({
                "operation": op,
                "result": "unknown_operation"
            })
    
    return {
        "synced": synced,
        "conflicts": conflicts
    }