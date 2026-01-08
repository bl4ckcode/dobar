import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock
from typing import Dict, Any


class TestAsyncPatternVerification:
    def test_all_gateway_methods_are_coroutines(self):
        import ast
        import inspect
        
        gateway_files = [
            'dobar_payment/gateways/stripe.py',
            'dobar_payment/gateways/paypal.py', 
            'dobar_payment/gateways/stone.py',
        ]
        
        gateway_classes = [
            'StripePaymentGateway',
            'PaypalPaymentGateway',
            'StonePaymentGateway',
        ]
        
        required_async = ['create_charge', 'refund_charge', 'capture_charge']
        
        for filepath, classname in zip(gateway_files, gateway_classes):
            with open(filepath) as f:
                tree = ast.parse(f.read())
            
            for node in ast.walk(tree):
                if isinstance(node, ast.ClassDef) and node.name == classname:
                    async_methods = {
                        item.name for item in node.body 
                        if isinstance(item, ast.AsyncFunctionDef)
                    }
                    
                    for method in required_async:
                        assert method in async_methods, \
                            f"{classname}.{method} must be async"


class TestPaymentEngineAsync:
    def test_engine_methods_are_coroutines(self):
        import ast
        
        with open('dobar_payment/factory.py') as f:
            tree = ast.parse(f.read())
        
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef) and node.name == 'PaymentEngine':
                async_methods = {
                    item.name for item in node.body 
                    if isinstance(item, ast.AsyncFunctionDef)
                }
                
                assert 'charge' in async_methods
                assert 'refund' in async_methods
                assert 'capture' in async_methods
                assert 'health_check' in async_methods


class TestCurrencyUtils:
    def test_normalize_currency_stripe(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('currency', 'dobar_payment/utils/currency.py')
        currency = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(currency)
        
        assert currency.normalize_currency("brl", "stripe") == "brl"
        assert currency.normalize_currency("USD", "stripe") == "usd"
    
    def test_normalize_currency_paypal(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('currency', 'dobar_payment/utils/currency.py')
        currency = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(currency)
        
        assert currency.normalize_currency("brl", "paypal") == "BRL"
        assert currency.normalize_currency("usd", "paypal") == "USD"
    
    def test_to_cents(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('currency', 'dobar_payment/utils/currency.py')
        currency = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(currency)
        
        assert currency.to_cents(10.00) == 1000
        assert currency.to_cents(99.99) == 9999
        assert currency.to_cents(0.01) == 1
    
    def test_from_cents(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('currency', 'dobar_payment/utils/currency.py')
        currency = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(currency)
        
        assert currency.from_cents(1000) == 10.00
        assert currency.from_cents(9999) == 99.99
        assert currency.from_cents(1) == 0.01
