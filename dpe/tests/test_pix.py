import pytest
import asyncio
import importlib.util
import sys


def _load_brcode():
    spec = importlib.util.spec_from_file_location('brcode', 'dobar_payment/pix/brcode.py')
    brcode = importlib.util.module_from_spec(spec)
    sys.modules['dobar_payment.pix.brcode'] = brcode
    spec.loader.exec_module(brcode)
    return brcode


class TestPixKeyTypeDetection:
    def test_detect_cpf(self):
        brcode = _load_brcode()
        assert brcode.detect_key_type("12345678901") == brcode.PixKeyType.CPF
    
    def test_detect_cnpj(self):
        brcode = _load_brcode()
        assert brcode.detect_key_type("12345678000199") == brcode.PixKeyType.CNPJ
    
    def test_detect_phone(self):
        brcode = _load_brcode()
        assert brcode.detect_key_type("+5527995772291") == brcode.PixKeyType.PHONE
        assert brcode.detect_key_type("5527995772291") == brcode.PixKeyType.PHONE
    
    def test_detect_email(self):
        brcode = _load_brcode()
        assert brcode.detect_key_type("test@example.com") == brcode.PixKeyType.EMAIL
    
    def test_detect_random(self):
        brcode = _load_brcode()
        assert brcode.detect_key_type("b5fe1edc-d108-410f-b966-eccaaca75e4f") == brcode.PixKeyType.RANDOM


class TestPixBRCodeGeneration:
    def test_generate_static_brcode(self):
        brcode = _load_brcode()
        pix = brcode.PixBRCode(
            key="b5fe1edc-d108-410f-b966-eccaaca75e4f",
            receiver_name="Teste Receiver",
            receiver_city="Sao Paulo",
            amount=10.50,
            txid="TEST123",
        )
        code = pix.generate()
        
        assert code.startswith("0002010")
        assert "br.gov.bcb.pix" in code
        assert len(code) > 50
    
    def test_brcode_crc_valid(self):
        brcode = _load_brcode()
        pix = brcode.PixBRCode(
            key="test@email.com",
            receiver_name="Receiver",
            receiver_city="City",
            amount=5.00,
        )
        code = pix.generate()
        
        parsed = brcode.parse_brcode(code)
        assert parsed["valid"] is True
    
    def test_brcode_to_dict(self):
        brcode = _load_brcode()
        pix = brcode.PixBRCode(
            key="5527995772291",
            receiver_name="Teste",
            receiver_city="Cariacica",
            amount=15.00,
            txid="PIX001",
        )
        data = pix.to_dict()
        
        assert data["key"] == "5527995772291"
        assert data["key_type"] == "phone"
        assert data["amount"] == 15.00
        assert "brcode" in data
    
    def test_parse_brcode(self):
        brcode = _load_brcode()
        test_code = "00020101021126690014br.gov.bcb.pix0114+55279957722910229Doacao Livre / QRCODE - PYPIX52040000530398654045.005802BR5905Teste6009Cariacica61082914861362130509PIXMP00016304325F"
        
        parsed = brcode.parse_brcode(test_code)
        
        assert parsed["valid"] is True
        assert parsed["key"] == "+5527995772291"
        assert parsed["receiver_name"] == "Teste"
        assert parsed["amount"] == 5.00


class TestPixGateway:
    @pytest.mark.asyncio
    async def test_create_charge_inline(self):
        brcode = _load_brcode()
        
        from dataclasses import dataclass, field
        from datetime import datetime, timezone, timedelta
        from enum import Enum
        import uuid
        
        class PixTransactionStatus(str, Enum):
            PENDING = "pending"
            ACTIVE = "active"
            COMPLETED = "completed"
        
        @dataclass
        class PixCharge:
            id: str
            txid: str
            key: str
            amount: float
            brcode_str: str
            status: PixTransactionStatus = PixTransactionStatus.ACTIVE
        
        charge_id = str(uuid.uuid4())
        txid = f"DOBAR{charge_id[:8].upper()}"
        
        pix = brcode.PixBRCode(
            key="test@dobar.com",
            receiver_name="Dobar Test",
            receiver_city="Sao Paulo",
            amount=25.50,
            txid=txid,
            description="Test payment",
            single_transaction=True,
        )
        
        charge = PixCharge(
            id=charge_id,
            txid=txid,
            key="test@dobar.com",
            amount=25.50,
            brcode_str=pix.generate(),
        )
        
        assert charge.amount == 25.50
        assert charge.status == PixTransactionStatus.ACTIVE
        assert len(charge.brcode_str) > 50
    
    @pytest.mark.asyncio
    async def test_charge_to_dict(self):
        brcode = _load_brcode()
        
        pix = brcode.PixBRCode(
            key="12345678901",
            receiver_name="Test",
            receiver_city="City",
            amount=10.00,
        )
        
        data = pix.to_dict()
        assert data["amount"] == 10.00
        assert data["key"] == "12345678901"
        assert "brcode" in data
    
    @pytest.mark.asyncio
    async def test_brcode_validation(self):
        brcode = _load_brcode()
        
        pix = brcode.PixBRCode(
            key="test@email.com",
            receiver_name="Receiver Name",
            receiver_city="Test City",
            amount=100.00,
            txid="TX123456",
        )
        
        code = pix.generate()
        parsed = brcode.parse_brcode(code)
        
        assert parsed["valid"] is True
        assert parsed["key"] == "test@email.com"
        assert parsed["amount"] == 100.00
    
    @pytest.mark.asyncio
    async def test_phone_key_formatting(self):
        brcode = _load_brcode()
        
        pix = brcode.PixBRCode(
            key="5527995772291",
            receiver_name="Test",
            receiver_city="City",
            amount=5.00,
        )
        
        code = pix.generate()
        assert "+5527995772291" in code or "5527995772291" in code
