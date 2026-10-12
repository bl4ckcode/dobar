from enum import Enum
from typing import Optional, Dict, Any
from dataclasses import dataclass
import re
from unicodedata import normalize


class PixKeyType(str, Enum):
    CPF = "cpf"
    CNPJ = "cnpj"
    PHONE = "phone"
    EMAIL = "email"
    RANDOM = "random"


@dataclass
class PixBRCode:
    key: str
    receiver_name: str
    receiver_city: str
    amount: float = 0.0
    txid: Optional[str] = None
    description: Optional[str] = None
    zipcode: Optional[str] = None
    single_transaction: bool = False
    
    @property
    def key_type(self) -> PixKeyType:
        return detect_key_type(self.key)
    
    def generate(self) -> str:
        key = self._format_key()
        
        payload_parts = [
            _tlv("00", "01"),
            _tlv("01", "12" if self.single_transaction else "11"),
            self._merchant_account_info(key),
            _tlv("52", "0000"),
            _tlv("53", "986"),
        ]
        
        if self.amount > 0:
            payload_parts.append(_tlv("54", f"{self.amount:.2f}"))
        
        payload_parts.extend([
            _tlv("58", "BR"),
            _tlv("59", _sanitize_text(self.receiver_name)[:25]),
            _tlv("60", _sanitize_text(self.receiver_city)[:15]),
        ])
        
        if self.zipcode:
            payload_parts.append(_tlv("61", _sanitize_text(self.zipcode)))
        
        payload_parts.append(self._additional_data())
        payload_parts.append("6304")
        
        payload = "".join(payload_parts)
        return payload + _crc16(payload)
    
    def _format_key(self) -> str:
        key_type = self.key_type
        if key_type == PixKeyType.PHONE:
            if not self.key.startswith("+55"):
                return f"+55{self.key}"
        return self.key
    
    def _merchant_account_info(self, key: str) -> str:
        gui = _tlv("00", "br.gov.bcb.pix")
        key_field = _tlv("01", key)
        desc = ""
        if self.description:
            desc = _tlv("02", _sanitize_text(self.description)[:72])
        return _tlv("26", f"{gui}{key_field}{desc}")
    
    def _additional_data(self) -> str:
        txid = self.txid if self.txid else "***"
        return _tlv("62", _tlv("05", _sanitize_text(txid)))
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "key": self.key,
            "key_type": self.key_type.value,
            "receiver_name": self.receiver_name,
            "receiver_city": self.receiver_city,
            "amount": self.amount,
            "txid": self.txid,
            "description": self.description,
            "brcode": self.generate(),
        }


def _tlv(tag: str, value: str) -> str:
    return f"{tag}{len(value):02d}{value}"


def _crc16(data: str) -> str:
    crc = 0xFFFF
    for byte in data.encode("utf-8"):
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = (crc << 1) ^ 0x1021
            else:
                crc <<= 1
    return f"{crc & 0xFFFF:04X}"


def _sanitize_text(text: str) -> str:
    normalized = normalize("NFD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^A-Za-z0-9$@%*+\-./:_ ]", "", normalized)


def detect_key_type(key: str) -> PixKeyType:
    key = key.strip()
    
    if re.match(r"^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", key.lower()):
        return PixKeyType.RANDOM
    
    if re.match(r"^[\w\.-]+@[\w\.-]+\.\w+$", key):
        return PixKeyType.EMAIL
    
    cleaned = re.sub(r"[\s\-\(\)\+]", "", key)
    if re.match(r"^55?\d{10,11}$", cleaned):
        return PixKeyType.PHONE
    
    digits = re.sub(r"\D", "", key)
    if len(digits) == 11:
        return PixKeyType.CPF
    if len(digits) == 14:
        return PixKeyType.CNPJ
    
    return PixKeyType.RANDOM


def parse_brcode(brcode: str) -> Dict[str, Any]:
    crc_idx = brcode.rfind("6304")
    if crc_idx == -1 or len(brcode[crc_idx:]) != 8:
        raise ValueError("Invalid BR Code: CRC field not found")
    
    payload = brcode[:crc_idx]
    provided_crc = brcode[-4:]
    calculated_crc = _crc16(brcode[:-4])
    
    is_valid = provided_crc == calculated_crc
    
    fields = _parse_tlv(payload)
    merchant_info = _parse_tlv(fields.get("26", ""))
    additional = _parse_tlv(fields.get("62", ""))
    
    return {
        "valid": is_valid,
        "crc_provided": provided_crc,
        "crc_calculated": calculated_crc,
        "key": merchant_info.get("01", ""),
        "description": merchant_info.get("02", ""),
        "receiver_name": fields.get("59", ""),
        "receiver_city": fields.get("60", ""),
        "amount": float(fields.get("54", "0")) if "54" in fields else 0.0,
        "txid": additional.get("05", ""),
        "single_transaction": fields.get("01") == "12",
    }


def _parse_tlv(data: str) -> Dict[str, str]:
    result = {}
    i = 0
    while i < len(data) - 3:
        tag = data[i:i+2]
        try:
            length = int(data[i+2:i+4])
        except ValueError:
            break
        value = data[i+4:i+4+length]
        result[tag] = value
        i += 4 + length
    return result
