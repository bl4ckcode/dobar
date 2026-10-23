import importlib.util
import json
import sys
import unittest
from pathlib import Path

import httpx
from pydantic import ValidationError

ROOT = Path(__file__).resolve().parents[3]
FIXTURE = json.loads(
    (ROOT / "tools/agent_workflow/fixtures/pix-checkout.json").read_text()
)


def load_checkout_module(name, relative_path):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


BE = load_checkout_module("checkout_be_schemas", "be/app/payment/schemas.py")
DPE = load_checkout_module("checkout_dpe_schemas", "dpe/dobar_payment/api/schemas.py")
CLIENT = load_checkout_module("checkout_be_client", "be/app/payment/dpe_client.py")


class PixWireContracts(unittest.IsolatedAsyncioTestCase):
    async def test_actual_bridge_payload_satisfies_local_dpe_schema(self):
        request = BE.DPEChargeRequest.model_validate(FIXTURE["frontend_request"])
        captured = []

        def provider_boundary(http_request):
            payload = json.loads(http_request.content)
            DPE.ChargeRequestAPI.model_validate(payload)
            self.assertEqual(payload, FIXTURE["dpe_request"])
            self.assertEqual(http_request.url.path, "/payments/charge")
            self.assertEqual(
                http_request.headers["X-Service-Auth"], "test-service-secret"
            )
            self.assertEqual(
                http_request.headers["X-Idempotency-Key"], payload["idempotency_key"]
            )
            self.assertTrue(http_request.headers["X-Request-ID"])
            self.assertNotIn("card", payload["payment_method"])
            response = DPE.ChargeResponseAPI.model_validate(FIXTURE["dpe_response"])
            captured.append(payload)
            return httpx.Response(200, json=response.model_dump(mode="json"))

        bridge = CLIENT.DPEClient(
            base_url="https://dpe.invalid", service_secret="test-service-secret"
        )
        async with httpx.AsyncClient(
            base_url=bridge.base_url, transport=httpx.MockTransport(provider_boundary)
        ) as client:
            bridge._client = client
            for _ in range(2):
                result = await bridge.charge(
                    order_id=request.order_id,
                    user_id=7,
                    bar_id=request.bar_id,
                    amount=request.amount,
                    currency=request.currency,
                    country=request.country,
                    payment_method=FIXTURE["frontend_request"]["payment_method"],
                    idempotency_key=FIXTURE["dpe_request"]["idempotency_key"],
                )
                BE.DPEChargeResponse.model_validate(result)
                for field, expected in FIXTURE["backend_response"].items():
                    self.assertEqual(result[field], expected)
                self.assertEqual(result["status"], "pending")
        self.assertEqual(captured[0], captured[1])

    async def test_zero_or_negative_amount_cannot_enter_local_dpe_request(self):
        for amount in (0, -1):
            with self.subTest(amount=amount), self.assertRaises(ValidationError):
                DPE.ChargeRequestAPI.model_validate(
                    {**FIXTURE["dpe_request"], "amount_cents": amount}
                )

    async def test_provider_error_remains_unpaid_with_error_identity(self):
        def failing_boundary(request):
            return httpx.Response(
                503,
                json={
                    "error_code": "GATEWAY_UNAVAILABLE",
                    "message": "Sandbox unavailable",
                    "details": {"retryable": True},
                },
            )

        bridge = CLIENT.DPEClient(
            base_url="https://dpe.invalid", service_secret="test-service-secret"
        )
        async with httpx.AsyncClient(
            base_url=bridge.base_url, transport=httpx.MockTransport(failing_boundary)
        ) as client:
            bridge._client = client
            result = await bridge.charge(
                order_id=101,
                user_id=7,
                bar_id=12,
                amount=59.9,
                currency="BRL",
                country="BR",
                payment_method={"type": "pix"},
                idempotency_key="fixture-error-attempt",
            )
        self.assertEqual(result["status"], "error")
        self.assertEqual(result["http_status"], 503)
        self.assertEqual(result["error_code"], "GATEWAY_UNAVAILABLE")
        self.assertNotIn("payment_id", result)


if __name__ == "__main__":
    unittest.main()
