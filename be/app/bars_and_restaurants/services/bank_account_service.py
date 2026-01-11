import os
import base64
import hashlib
from cryptography.fernet import Fernet
from typing import Optional
import re

ENCRYPTION_KEY = os.getenv("BANK_ACCOUNT_ENCRYPTION_KEY")

def _get_fernet():
    if not ENCRYPTION_KEY:
        key = Fernet.generate_key()
        print("⚠️ BANK_ACCOUNT_ENCRYPTION_KEY not set, using temporary key")
        return Fernet(key)
    key_bytes = hashlib.sha256(ENCRYPTION_KEY.encode()).digest()
    return Fernet(base64.urlsafe_b64encode(key_bytes))


def encrypt_value(value: str) -> str:
    if not value:
        return None
    fernet = _get_fernet()
    return fernet.encrypt(value.encode()).decode()


def decrypt_value(encrypted: str) -> str:
    if not encrypted:
        return None
    fernet = _get_fernet()
    return fernet.decrypt(encrypted.encode()).decode()


def mask_account_number(value: str, visible_digits: int = 4) -> str:
    if not value:
        return None
    clean = re.sub(r"[^\dA-Za-z]", "", value)
    if len(clean) <= visible_digits:
        return clean
    return "*" * (len(clean) - visible_digits) + clean[-visible_digits:]


def validate_bank_account_for_country(country_code: str, data: dict) -> tuple[bool, Optional[str]]:
    cc = country_code.upper()
    
    if cc == "BR":
        if not data.get("bank_code"):
            return False, "Bank code is required for Brazil"
        if not data.get("branch_code"):
            return False, "Branch code (agência) is required for Brazil"
        if not data.get("account_number"):
            return False, "Account number is required for Brazil"
        bank_code = data.get("bank_code", "")
        if not re.match(r"^\d{3,5}$", bank_code):
            return False, "Bank code must be 3-5 digits"
        return True, None
    
    elif cc == "MX":
        clabe = data.get("clabe", "")
        clean = re.sub(r"[^\d]", "", clabe)
        if len(clean) != 18:
            return False, "CLABE must be exactly 18 digits"
        return True, None
    
    elif cc == "AR":
        cbu = data.get("cbu", "")
        clean = re.sub(r"[^\d]", "", cbu)
        if len(clean) != 22:
            return False, "CBU must be exactly 22 digits"
        return True, None
    
    elif cc == "US":
        routing = data.get("routing_number", "")
        clean = re.sub(r"[^\d]", "", routing)
        if len(clean) != 9:
            return False, "Routing number must be exactly 9 digits"
        if not data.get("account_number"):
            return False, "Account number is required for USA"
        return True, None
    
    elif cc == "CO":
        if not data.get("bank_code"):
            return False, "Bank code is required for Colombia"
        if not data.get("account_number"):
            return False, "Account number is required for Colombia"
        return True, None
    
    elif cc in ["PT", "ES"]:
        return True, None
    
    else:
        return True, None


BRAZILIAN_BANKS = {
    "001": "Banco do Brasil",
    "033": "Santander",
    "104": "Caixa Econômica Federal",
    "237": "Bradesco",
    "341": "Itaú Unibanco",
    "422": "Safra",
    "745": "Citibank",
    "077": "Banco Inter",
    "260": "Nubank",
    "336": "C6 Bank",
    "212": "Banco Original",
    "756": "Sicoob",
    "748": "Sicredi",
    "021": "Banestes",
    "070": "BRB",
    "136": "Unicred",
    "323": "Mercado Pago",
    "380": "PicPay",
    "290": "PagSeguro",
}


def get_bank_name(bank_code: str) -> Optional[str]:
    return BRAZILIAN_BANKS.get(bank_code)
