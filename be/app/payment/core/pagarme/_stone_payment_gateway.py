# This module is internal and should not be imported directly.
# Use `get_payment_gateway()` from `factory.py` instead.

from app.payment.core.interfaces import PaymentGateway

from app.payment.pagarme_sdk.pagarmeapisdk.pagarmeapisdk_client import PagarmeapisdkClient
from app.payment.pagarme_sdk.pagarmeapisdk.http.auth.basic_auth import BasicAuthCredentials
from app.payment.pagarme_sdk.pagarmeapisdk.configuration import Environment
from app.payment.pagarme_sdk.pagarmeapisdk.exceptions.error_exception import ErrorException

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
        charges_controller = self.client.charges

        body = {
            "amount": amount,
            "currency": currency,
            "customer": customer,
            "payment": payment_method
        }

        try:
            response = charges_controller.create_charge(body)
            return response
        except ErrorException as e:
            # Log error, handle exceptions properly
            logging.error(f"Error occurred while creating charge: {e}")
            raise e

    def refund_charge(self, charge_id: str, amount: int = None) -> dict:
        charges_controller = self.client.charges

        body = {"amount": amount} if amount else {}

        try:
            response = charges_controller.cancel_charge(charge_id, body)
            return response
        except ErrorException as e:
            # Log error, handle exceptions properly
            logging.error(f"Error occurred while refunding charge: {e}")
            raise e
