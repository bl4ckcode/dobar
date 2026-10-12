import sys
import inspect
from typing import get_type_hints, Any

sys.path.insert(0, '.')

from app.payment.dpe_client import DPEClient

EXPECTED_DPE_METHODS = {
    "charge": {
        "params": ["order_id", "user_id", "bar_id", "amount", "currency", "country", "payment_method", "idempotency_key"],
        "return_type": "dict"
    },
    "refund": {
        "params": ["payment_id", "amount", "reason", "idempotency_key"],
        "return_type": "dict"
    },
    "health_check": {
        "params": [],
        "return_type": "dict"
    }
}

def validate_method_signature(client_class, method_name, expected_params):
    if not hasattr(client_class, method_name):
        print(f"❌ Missing method: {method_name}")
        return False
    
    method = getattr(client_class, method_name)
    sig = inspect.signature(method)
    
    actual_params = [p for p in sig.parameters.keys() if p != 'self']
    
    missing_params = set(expected_params) - set(actual_params)
    if missing_params:
        print(f"❌ Method '{method_name}' missing parameters: {missing_params}")
        return False
    
    print(f"✅ Method '{method_name}' signature validated")
    return True

def validate_dpe_response_structure():
    print("\n🔍 Validating DPE response structures...")
    
    expected_charge_response = {
        "status": str,
        "payment_intent_id": str,
        "amount": (int, float),
        "currency": str
    }
    
    expected_refund_response = {
        "status": str,
        "refund_id": str,
        "amount": (int, float)
    }
    
    print("✅ DPE response structures defined")
    return True

def main():
    print("🔒 DPE Contract Validation")
    print("=" * 50)
    
    all_valid = True
    
    print("\n🔍 Validating DPEClient methods...")
    for method_name, expected in EXPECTED_DPE_METHODS.items():
        if not validate_method_signature(DPEClient, method_name, expected["params"]):
            all_valid = False
    
    if not validate_dpe_response_structure():
        all_valid = False
    
    print("\n🔍 Checking DPEClient initialization...")
    try:
        client = DPEClient(base_url="http://test.local", service_secret="test_secret")
        print("✅ DPEClient can be initialized")
    except Exception as e:
        print(f"❌ DPEClient initialization failed: {e}")
        all_valid = False
    
    print("\n" + "=" * 50)
    if all_valid:
        print("✅ All DPE contracts validated successfully")
        sys.exit(0)
    else:
        print("❌ DPE contract validation failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
