from typing import Optional, Literal
from pydantic import BaseModel, field_validator
from datetime import datetime
import re


class BankAccountBrazil(BaseModel):
    bank_code: str
    branch_code: str
    account_number: str
    account_type: Literal["checking", "savings"] = "checking"
    pix_key: Optional[str] = None
    pix_key_type: Optional[Literal["cpf", "cnpj", "email", "phone", "random"]] = None
    
    @field_validator("bank_code")
    @classmethod
    def validate_bank_code(cls, v):
        if not re.match(r"^\d{3,5}$", v):
            raise ValueError("Bank code must be 3-5 digits")
        return v
    
    @field_validator("branch_code")
    @classmethod
    def validate_branch_code(cls, v):
        clean = re.sub(r"[^\d]", "", v)
        if len(clean) < 1 or len(clean) > 6:
            raise ValueError("Branch code must be 1-6 digits")
        return clean


class BankAccountMexico(BaseModel):
    clabe: str
    account_holder_name: str
    
    @field_validator("clabe")
    @classmethod
    def validate_clabe(cls, v):
        clean = re.sub(r"[^\d]", "", v)
        if len(clean) != 18:
            raise ValueError("CLABE must be exactly 18 digits")
        return clean


class BankAccountArgentina(BaseModel):
    cbu: str
    account_holder_name: str
    
    @field_validator("cbu")
    @classmethod
    def validate_cbu(cls, v):
        clean = re.sub(r"[^\d]", "", v)
        if len(clean) != 22:
            raise ValueError("CBU must be exactly 22 digits")
        return clean


class BankAccountUSA(BaseModel):
    routing_number: str
    account_number: str
    account_type: Literal["checking", "savings"] = "checking"
    account_holder_name: Optional[str] = None
    
    @field_validator("routing_number")
    @classmethod
    def validate_routing(cls, v):
        clean = re.sub(r"[^\d]", "", v)
        if len(clean) != 9:
            raise ValueError("Routing number must be exactly 9 digits")
        return clean


class BankAccountColombia(BaseModel):
    bank_code: str
    account_number: str
    account_type: Literal["checking", "savings"] = "checking"
    account_holder_name: str


class BankAccountCreate(BaseModel):
    country_code: str
    
    bank_code: Optional[str] = None
    branch_code: Optional[str] = None
    account_number: Optional[str] = None
    account_type: Optional[str] = None
    
    pix_key: Optional[str] = None
    pix_key_type: Optional[str] = None
    
    clabe: Optional[str] = None
    cbu: Optional[str] = None
    routing_number: Optional[str] = None
    account_holder_name: Optional[str] = None


class BankAccountResponse(BaseModel):
    id: int
    bar_id: int
    country_code: str
    
    bank_code: Optional[str] = None
    branch_code: Optional[str] = None
    account_number_masked: Optional[str] = None
    account_type: Optional[str] = None
    
    pix_key_masked: Optional[str] = None
    pix_key_type: Optional[str] = None
    
    clabe_masked: Optional[str] = None
    cbu_masked: Optional[str] = None
    routing_number: Optional[str] = None
    account_holder_name: Optional[str] = None
    
    is_verified: bool = False
    created_at: datetime
    updated_at: datetime


class BankAccountUpdate(BaseModel):
    bank_code: Optional[str] = None
    branch_code: Optional[str] = None
    account_number: Optional[str] = None
    account_type: Optional[str] = None
    pix_key: Optional[str] = None
    pix_key_type: Optional[str] = None
    clabe: Optional[str] = None
    cbu: Optional[str] = None
    routing_number: Optional[str] = None
    account_holder_name: Optional[str] = None
