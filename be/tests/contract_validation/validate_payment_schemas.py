import sys
import json
from decimal import Decimal
from datetime import datetime, timezone
from sqlalchemy import inspect, create_engine
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, '.')

from app.bars_and_restaurants.models.wallet_models import (
    CashbackLedger, UserWallet, BarWallet, CashbackType, CashbackStatus, FundingSource
)
from app.payment.models import IdempotencyKey

EXPECTED_SCHEMAS = {
    "cashback_ledger": {
        "id": "INTEGER",
        "user_id": "INTEGER",
        "bar_id": "INTEGER",
        "order_id": "INTEGER",
        "amount": "NUMERIC",
        "type": "VARCHAR",
        "status": "VARCHAR",
        "funded_by": "VARCHAR",
        "created_at": "DATETIME",
        "expires_at": "DATETIME"
    },
    "user_wallet": {
        "user_id": "INTEGER",
        "available_balance": "NUMERIC",
        "pending_balance": "NUMERIC",
        "last_updated": "DATETIME"
    },
    "bar_wallet": {
        "bar_id": "INTEGER",
        "available_balance": "NUMERIC",
        "reserved_balance": "NUMERIC",
        "last_updated": "DATETIME"
    }
}

def validate_table_schema(engine, table_name, expected_columns):
    inspector = inspect(engine)
    
    if table_name not in inspector.get_table_names():
        print(f"❌ Table '{table_name}' does not exist")
        return False
    
    columns = {col['name']: str(col['type']) for col in inspector.get_columns(table_name)}
    
    errors = []
    for col_name, expected_type in expected_columns.items():
        if col_name not in columns:
            errors.append(f"  ❌ Missing column: {col_name}")
        elif not columns[col_name].startswith(expected_type):
            errors.append(f"  ❌ Column '{col_name}' type mismatch: expected {expected_type}, got {columns[col_name]}")
    
    if errors:
        print(f"❌ Schema validation failed for '{table_name}':")
        for error in errors:
            print(error)
        return False
    
    print(f"✅ Schema validation passed for '{table_name}'")
    return True

def validate_enum_values():
    print("\n🔍 Validating enum values...")
    
    expected_enums = {
        "CashbackType": ["EARN", "REDEEM", "ADJUST", "EXPIRE"],
        "CashbackStatus": ["PENDING", "AVAILABLE", "USED", "EXPIRED"],
        "FundingSource": ["BAR", "BARZ", "SPONSORED"]
    }
    
    actual_enums = {
        "CashbackType": [e.value for e in CashbackType],
        "CashbackStatus": [e.value for e in CashbackStatus],
        "FundingSource": [e.value for e in FundingSource]
    }
    
    all_valid = True
    for enum_name, expected_values in expected_enums.items():
        actual_values = actual_enums[enum_name]
        if set(expected_values) != set(actual_values):
            print(f"❌ Enum '{enum_name}' mismatch:")
            print(f"  Expected: {expected_values}")
            print(f"  Actual: {actual_values}")
            all_valid = False
        else:
            print(f"✅ Enum '{enum_name}' validated")
    
    return all_valid

def main():
    print("🔒 Payment Schema Validation")
    print("=" * 50)
    
    engine = create_engine("sqlite:///./test.db")
    
    from app.database import Base
    from app.auth.auth_models import User
    from app.bars_and_restaurants.models.relational_models import Bar, Order
    
    Base.metadata.create_all(bind=engine)
    
    all_valid = True
    
    for table_name, expected_columns in EXPECTED_SCHEMAS.items():
        if not validate_table_schema(engine, table_name, expected_columns):
            all_valid = False
    
    if not validate_enum_values():
        all_valid = False
    
    print("\n" + "=" * 50)
    if all_valid:
        print("✅ All payment schemas validated successfully")
        sys.exit(0)
    else:
        print("❌ Payment schema validation failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
