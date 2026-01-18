#!/usr/bin/env python3
import asyncio
import httpx
import uuid
import time
from concurrent.futures import ThreadPoolExecutor

BASE_URL = "http://localhost:8000"
AUTH_TOKEN = None  # Will be set after login

async def get_auth_token():
    print("\n🔐 Getting auth token...")
    print("   (In real test, you'd use Firebase token)")
    print("   For now, use Swagger UI or set TEST_TOKEN env var")
    return None

async def test_charge(bar_id: int, amount: float, payment_type: str = "card"):
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30) as client:
        headers = {"Authorization": f"Bearer {AUTH_TOKEN}"} if AUTH_TOKEN else {}
        
        payload = {
            "order_id": 12345,
            "bar_id": bar_id,
            "amount": amount,
            "currency": "BRL",
            "country": "BR",
            "payment_method": {
                "type": payment_type,
                "token": "tok_test_visa_approved",
                "provider": "stripe",
                "installments": 1
            },
            "metadata": {"table": "5", "test": True}
        }
        
        idempotency_key = str(uuid.uuid4())
        headers["X-Idempotency-Key"] = idempotency_key
        
        print(f"\n💳 Testing charge: R${amount:.2f} to bar {bar_id}")
        print(f"   Idempotency key: {idempotency_key[:8]}...")
        
        response = await client.post("/payments/v2/charge", json=payload, headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Success! Payment ID: {data.get('payment_id')}")
            print(f"   Gateway: {data.get('gateway')}")
            return data
        else:
            print(f"   ❌ Failed: {response.status_code}")
            print(f"   {response.text}")
            return None

async def test_pix(order_id: int, bar_id: int, amount: float):
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30) as client:
        headers = {"Authorization": f"Bearer {AUTH_TOKEN}"} if AUTH_TOKEN else {}
        
        payload = {
            "order_id": order_id,
            "bar_id": bar_id,
            "amount": amount,
            "description": f"Mesa 5 - Pedido #{order_id}",
            "expires_in": 3600
        }
        
        print(f"\n📱 Testing PIX: R${amount:.2f}")
        
        response = await client.post("/pix/generate", json=payload, headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ PIX generated!")
            print(f"   BR Code: {data.get('brcode', '')[:50]}...")
            print(f"   Expires: {data.get('expires_at')}")
            return data
        else:
            print(f"   ❌ Failed: {response.status_code}")
            print(f"   {response.text}")
            return None

async def test_wallet_balance(user_id: int = None):
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30) as client:
        headers = {"Authorization": f"Bearer {AUTH_TOKEN}"} if AUTH_TOKEN else {}
        
        print(f"\n💰 Testing wallet balance...")
        
        response = await client.get("/wallet/", headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Wallet found!")
            print(f"   Available: R${data.get('available_balance', 0):.2f}")
            print(f"   Pending: R${data.get('pending_balance', 0):.2f}")
            return data
        else:
            print(f"   ❌ Failed: {response.status_code}")
            return None

async def test_concurrent_wallet_redeem(user_id: int, amount: float, bar_id: int, num_requests: int = 5):
    print(f"\n🔥 Testing {num_requests} CONCURRENT wallet redeems of R${amount:.2f}...")
    print("   (Only 1 should succeed if balance is exactly {amount})")
    
    async def single_redeem(i):
        async with httpx.AsyncClient(base_url=BASE_URL, timeout=30) as client:
            headers = {"Authorization": f"Bearer {AUTH_TOKEN}"} if AUTH_TOKEN else {}
            headers["X-Idempotency-Key"] = str(uuid.uuid4())
            
            payload = {"amount": amount}
            
            start = time.time()
            response = await client.post(
                f"/wallet/redeem?bar_id={bar_id}",
                json=payload,
                headers=headers
            )
            elapsed = time.time() - start
            
            return {
                "request": i,
                "status": response.status_code,
                "elapsed_ms": int(elapsed * 1000),
                "data": response.json() if response.status_code < 500 else response.text
            }
    
    tasks = [single_redeem(i) for i in range(num_requests)]
    results = await asyncio.gather(*tasks)
    
    successes = [r for r in results if r["status"] == 200]
    conflicts = [r for r in results if r["status"] == 409]
    failures = [r for r in results if r["status"] not in (200, 409)]
    
    print(f"\n   Results:")
    print(f"   ✅ Successes: {len(successes)}")
    print(f"   🔒 Conflicts (lock): {len(conflicts)}")
    print(f"   ❌ Failures: {len(failures)}")
    
    for r in results:
        status_icon = "✅" if r["status"] == 200 else "🔒" if r["status"] == 409 else "❌"
        print(f"   {status_icon} Request {r['request']}: {r['status']} ({r['elapsed_ms']}ms)")
    
    return results

async def test_idempotency():
    print("\n🔄 Testing idempotency (same key = same response)...")
    
    idempotency_key = str(uuid.uuid4())
    
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30) as client:
        headers = {"Authorization": f"Bearer {AUTH_TOKEN}"} if AUTH_TOKEN else {}
        headers["X-Idempotency-Key"] = idempotency_key
        
        payload = {
            "order_id": 99999,
            "bar_id": 1,
            "amount": 10.00,
            "currency": "BRL",
            "country": "BR",
            "payment_method": {"type": "card", "token": "tok_test", "installments": 1}
        }
        
        r1 = await client.post("/payments/v2/charge", json=payload, headers=headers)
        r2 = await client.post("/payments/v2/charge", json=payload, headers=headers)
        
        if r1.status_code == 200 and r2.status_code == 200:
            d1, d2 = r1.json(), r2.json()
            if d1.get("payment_id") == d2.get("payment_id"):
                print(f"   ✅ Same payment_id returned: {d1.get('payment_id')}")
            else:
                print(f"   ❌ Different payment_ids! {d1.get('payment_id')} vs {d2.get('payment_id')}")
        else:
            print(f"   Request 1: {r1.status_code}")
            print(f"   Request 2: {r2.status_code}")

async def main():
    print("=" * 60)
    print("🧪 BARZ PAYMENT TESTING SCRIPT")
    print("=" * 60)
    print("\nMake sure:")
    print("  1. Backend is running: uvicorn app.main:app --reload")
    print("  2. DPE is running (or using stub mode)")
    print("  3. You have a valid auth token (or endpoints allow anon)")
    
    print("\n" + "=" * 60)
    print("Available tests:")
    print("  1. test_charge(bar_id, amount)")
    print("  2. test_pix(order_id, bar_id, amount)")
    print("  3. test_wallet_balance()")
    print("  4. test_concurrent_wallet_redeem(user_id, amount, bar_id, num_requests)")
    print("  5. test_idempotency()")
    print("=" * 60)
    
    # Example: Run all tests
    # await test_charge(bar_id=1, amount=50.00)
    # await test_pix(order_id=123, bar_id=1, amount=25.00)
    # await test_wallet_balance()
    # await test_concurrent_wallet_redeem(user_id=1, amount=5.00, bar_id=1, num_requests=5)
    # await test_idempotency()

if __name__ == "__main__":
    asyncio.run(main())
