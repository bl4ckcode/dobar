# This module is internal and should not be imported directly.
# Use `get_payment_gateway()` from `factory.py` instead.

from typing import Optional
from app.payment.core.interfaces import PaymentGateway
from app.payment.utils.currency import normalize_currency

from pagarmeapisdk.pagarmeapisdk_client import PagarmeapisdkClient
from pagarmeapisdk.http.auth.basic_auth import BasicAuthCredentials
from pagarmeapisdk.configuration import Environment
from pagarmeapisdk.exceptions.error_exception import ErrorException
from pagarmeapisdk.models.create_charge_request import CreateChargeRequest
from pagarmeapisdk.models.create_cancel_charge_request import CreateCancelChargeRequest
from pagarmeapisdk.models.create_customer_request import CreateCustomerRequest
from pagarmeapisdk.models.create_payment_request import CreatePaymentRequest
from pagarmeapisdk.models.create_credit_card_payment_request import CreateCreditCardPaymentRequest
from pagarmeapisdk.models.create_card_request import CreateCardRequest

from dotenv import load_dotenv

import os
import logging

load_dotenv()

def get_pagarme_client():
    username = os.getenv('PAGARME_USERNAME')
    password = os.getenv('PAGARME_PASSWORD')

    if not username:
        raise ValueError("Pagar.me API key is missing in .env file.")

    client = PagarmeapisdkClient(
        basic_auth_credentials=BasicAuthCredentials(
            username=username,
            password=password
        ),
        environment=Environment.PRODUCTION  # or Environment.SANDBOX
    )

    return client

class StonePaymentGateway(PaymentGateway):
    def __init__(self, config: dict):
        self.client = get_pagarme_client()

    def create_charge(self, amount: int, currency: str, customer: dict, payment_method: dict) -> dict:
        customer_model = self._build_customer_model(customer)
        credit_card = self._build_credit_card_model(payment_method)
        payment_model = self._build_payment_model(payment_method, credit_card, amount)
        charge_request = self._build_charge_request(amount, customer_model, payment_model)

        try:
            return self.client.charges.create_charge(charge_request)
        except ErrorException as e:
            logging.error(f"Error occurred while creating charge: {e}")
            raise e

    def _build_customer_model(self, customer: dict) -> CreateCustomerRequest:
        return CreateCustomerRequest(
            name=customer["name"],
            email=customer["email"],
            document=customer["document"]
        )

    def _build_credit_card_model(self, payment_method: dict) -> CreateCreditCardPaymentRequest:
        card = CreateCardRequest(
            number=payment_method["card"]["number"],
            holder_name=payment_method["card"]["holder_name"],
            exp_month=payment_method["card"]["exp_month"],
            exp_year=payment_method["card"]["exp_year"],
            cvv=payment_method["card"]["cvv"]
        )
        return CreateCreditCardPaymentRequest(
            card=card,
            installments=payment_method.get("installments", 1),
            capture=payment_method.get("capture", True)
        )

    def _build_payment_model(self, payment_method: dict, credit_card: CreateCreditCardPaymentRequest, amount: int) -> CreatePaymentRequest:
        return CreatePaymentRequest(
            payment_method="credit_card",
            credit_card=credit_card,
            amount=amount
        )

    def _build_charge_request(self, amount: int, customer: CreateCustomerRequest, payment: CreatePaymentRequest) -> CreateChargeRequest:
        return CreateChargeRequest(
            amount=amount,
            customer=customer,
            payment=payment,
            order_id="ORDER_XYZ"
        )

    def refund_charge(
        self,
        charge_id: Optional[str] = None,
        payment_intent_id: Optional[str] = None,
        amount: Optional[float] = None
    ) -> dict:
        try:
            if not charge_id:
                raise ValueError("Stone requires a charge_id to refund.")

            cancel_request = (
                CreateCancelChargeRequest(amount=int(amount * 100))  # Convert to cents
                if amount else
                CreateCancelChargeRequest()
            )

            response = self.client.charges.cancel_charge(charge_id, cancel_request)
            return {
                "status": "success",
                "refund_id": response.id,
                "amount_refunded": response.amount,
                "status_stone": response.status
            }

        except ErrorException as e:
            logging.error(f"Error occurred while refunding charge {charge_id}: {e}")
            return {"status": "failure", "error": str(e)}
        except Exception as e:
            logging.error(f"Unexpected error: {e}")
            return {"status": "failure", "error": str(e)}
