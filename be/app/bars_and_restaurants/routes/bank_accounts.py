from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.auth.rbac_middleware import get_current_user, AuthUser
from app.errors import APIError
from ..models.bank_account import BarBankAccount
from ..models.relational_models import Bar
from ..schemas.bank_account import BankAccountCreate, BankAccountResponse, BankAccountUpdate
from ..services import bank_account_service as bas

bank_accounts_router = APIRouter(prefix="/bars/{bar_id}/bank-account", tags=["Bank Accounts"])


def get_bar_or_404(bar_id: int, db: Session) -> Bar:
    bar = db.query(Bar).filter(Bar.id == bar_id).first()
    if not bar:
        raise APIError.not_found("Bar not found")
    return bar


def check_bar_ownership(bar: Bar, user: AuthUser):
    if bar.owner_id != user.user_id:
        raise APIError.forbidden("You don't have permission to manage this bar's bank account")


@bank_accounts_router.get("", response_model=BankAccountResponse)
async def get_bank_account(
    bar_id: int,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(get_current_user),
):
    bar = get_bar_or_404(bar_id, db)
    check_bar_ownership(bar, current_user)
    
    account = db.query(BarBankAccount).filter(BarBankAccount.bar_id == bar_id).first()
    if not account:
        raise APIError.not_found("No bank account configured for this bar")
    
    return BankAccountResponse(
        id=account.id,
        bar_id=account.bar_id,
        country_code=account.country_code,
        bank_code=account.bank_code,
        branch_code=account.branch_code,
        account_number_masked=bas.mask_account_number(
            bas.decrypt_value(account.account_number_encrypted)
        ) if account.account_number_encrypted else None,
        account_type=account.account_type,
        pix_key_masked=bas.mask_account_number(
            bas.decrypt_value(account.pix_key_encrypted)
        ) if account.pix_key_encrypted else None,
        pix_key_type=account.pix_key_type,
        clabe_masked=bas.mask_account_number(
            bas.decrypt_value(account.clabe_encrypted)
        ) if account.clabe_encrypted else None,
        cbu_masked=bas.mask_account_number(
            bas.decrypt_value(account.cbu_encrypted)
        ) if account.cbu_encrypted else None,
        routing_number=account.routing_number,
        account_holder_name=account.account_holder_name,
        is_verified=account.is_verified,
        created_at=account.created_at,
        updated_at=account.updated_at,
    )


@bank_accounts_router.post("", response_model=BankAccountResponse)
async def create_bank_account(
    bar_id: int,
    data: BankAccountCreate,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(get_current_user),
):
    bar = get_bar_or_404(bar_id, db)
    check_bar_ownership(bar, current_user)
    
    existing = db.query(BarBankAccount).filter(BarBankAccount.bar_id == bar_id).first()
    if existing:
        raise APIError.conflict("Bank account already exists for this bar. Use PUT to update.")
    
    valid, error = bas.validate_bank_account_for_country(data.country_code, data.model_dump())
    if not valid:
        raise APIError.validation_error(error)
    
    account = BarBankAccount(
        bar_id=bar_id,
        country_code=data.country_code.upper(),
        bank_code=data.bank_code,
        branch_code=data.branch_code,
        account_number_encrypted=bas.encrypt_value(data.account_number) if data.account_number else None,
        account_type=data.account_type,
        pix_key_encrypted=bas.encrypt_value(data.pix_key) if data.pix_key else None,
        pix_key_type=data.pix_key_type,
        clabe_encrypted=bas.encrypt_value(data.clabe) if data.clabe else None,
        cbu_encrypted=bas.encrypt_value(data.cbu) if data.cbu else None,
        routing_number=data.routing_number,
        account_holder_name=data.account_holder_name,
    )
    
    db.add(account)
    db.commit()
    db.refresh(account)
    
    return BankAccountResponse(
        id=account.id,
        bar_id=account.bar_id,
        country_code=account.country_code,
        bank_code=account.bank_code,
        branch_code=account.branch_code,
        account_number_masked=bas.mask_account_number(data.account_number),
        account_type=account.account_type,
        pix_key_masked=bas.mask_account_number(data.pix_key),
        pix_key_type=account.pix_key_type,
        clabe_masked=bas.mask_account_number(data.clabe),
        cbu_masked=bas.mask_account_number(data.cbu),
        routing_number=account.routing_number,
        account_holder_name=account.account_holder_name,
        is_verified=account.is_verified,
        created_at=account.created_at,
        updated_at=account.updated_at,
    )


@bank_accounts_router.put("", response_model=BankAccountResponse)
async def update_bank_account(
    bar_id: int,
    data: BankAccountUpdate,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(get_current_user),
):
    bar = get_bar_or_404(bar_id, db)
    check_bar_ownership(bar, current_user)
    
    account = db.query(BarBankAccount).filter(BarBankAccount.bar_id == bar_id).first()
    if not account:
        raise APIError.not_found("No bank account found. Use POST to create one.")
    
    update_data = data.model_dump(exclude_unset=True)
    
    if "account_number" in update_data and update_data["account_number"]:
        account.account_number_encrypted = bas.encrypt_value(update_data.pop("account_number"))
    if "pix_key" in update_data and update_data["pix_key"]:
        account.pix_key_encrypted = bas.encrypt_value(update_data.pop("pix_key"))
    if "clabe" in update_data and update_data["clabe"]:
        account.clabe_encrypted = bas.encrypt_value(update_data.pop("clabe"))
    if "cbu" in update_data and update_data["cbu"]:
        account.cbu_encrypted = bas.encrypt_value(update_data.pop("cbu"))
    
    for key, value in update_data.items():
        if value is not None:
            setattr(account, key, value)
    
    account.is_verified = False
    
    db.commit()
    db.refresh(account)
    
    return BankAccountResponse(
        id=account.id,
        bar_id=account.bar_id,
        country_code=account.country_code,
        bank_code=account.bank_code,
        branch_code=account.branch_code,
        account_number_masked=bas.mask_account_number(
            bas.decrypt_value(account.account_number_encrypted)
        ) if account.account_number_encrypted else None,
        account_type=account.account_type,
        pix_key_masked=bas.mask_account_number(
            bas.decrypt_value(account.pix_key_encrypted)
        ) if account.pix_key_encrypted else None,
        pix_key_type=account.pix_key_type,
        clabe_masked=bas.mask_account_number(
            bas.decrypt_value(account.clabe_encrypted)
        ) if account.clabe_encrypted else None,
        cbu_masked=bas.mask_account_number(
            bas.decrypt_value(account.cbu_encrypted)
        ) if account.cbu_encrypted else None,
        routing_number=account.routing_number,
        account_holder_name=account.account_holder_name,
        is_verified=account.is_verified,
        created_at=account.created_at,
        updated_at=account.updated_at,
    )


@bank_accounts_router.delete("")
async def delete_bank_account(
    bar_id: int,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(get_current_user),
):
    bar = get_bar_or_404(bar_id, db)
    check_bar_ownership(bar, current_user)
    
    account = db.query(BarBankAccount).filter(BarBankAccount.bar_id == bar_id).first()
    if not account:
        raise APIError.not_found("No bank account found")
    
    db.delete(account)
    db.commit()
    
    return {"message": "Bank account deleted successfully"}
