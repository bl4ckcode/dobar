import re
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List, Literal
from app.database import database
from app.auth.rbac_middleware import get_current_user, AuthUser
from app.bars_and_restaurants.models.relational_models import UserDocument
from app.errors import APIError, ErrorCode

user_documents_router = APIRouter(prefix="/users/me", tags=["User Documents"])

VALID_DOCUMENT_TYPES = {"cpf", "rg", "cnh", "passport"}


def validate_cpf(cpf: str) -> bool:
    cpf = re.sub(r'[^\d]', '', cpf)
    if len(cpf) != 11:
        return False
    if cpf == cpf[0] * 11:
        return False
    sum1 = sum(int(cpf[i]) * (10 - i) for i in range(9))
    d1 = 11 - (sum1 % 11)
    d1 = 0 if d1 >= 10 else d1
    sum2 = sum(int(cpf[i]) * (11 - i) for i in range(10))
    d2 = 11 - (sum2 % 11)
    d2 = 0 if d2 >= 10 else d2
    return cpf[-2:] == f"{d1}{d2}"


class DocumentCreate(BaseModel):
    type: Literal["cpf", "rg", "cnh", "passport"]
    number: str
    issuing_authority: Optional[str] = None
    issue_date: Optional[datetime] = None
    expiry_date: Optional[datetime] = None
    verified: bool = False


class DocumentResponse(BaseModel):
    id: int
    user_id: int
    type: str
    number: str
    issuing_authority: Optional[str] = None
    issue_date: Optional[datetime] = None
    expiry_date: Optional[datetime] = None
    verified: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


@user_documents_router.post("/documents", response_model=DocumentResponse, status_code=201)
async def create_or_update_document(
    data: DocumentCreate,
    current_user: AuthUser = Depends(get_current_user)
):
    if data.type == "cpf" and not validate_cpf(data.number):
        raise APIError(
            status_code=422,
            error_code=ErrorCode.INVALID_CPF,
            message="Invalid CPF number"
        )

    existing = await database.fetch_one(
        UserDocument.__table__.select().where(
            (UserDocument.user_id == current_user.id) &
            (UserDocument.type == data.type)
        )
    )

    now = datetime.utcnow()

    if existing:
        await database.execute(
            UserDocument.__table__.update()
            .where(UserDocument.id == existing["id"])
            .values(
                number=data.number,
                issuing_authority=data.issuing_authority,
                issue_date=data.issue_date,
                expiry_date=data.expiry_date,
                verified=data.verified,
                updated_at=now
            )
        )
        updated = await database.fetch_one(
            UserDocument.__table__.select().where(UserDocument.id == existing["id"])
        )
        return updated

    doc_id = await database.execute(
        UserDocument.__table__.insert().values(
            user_id=current_user.id,
            type=data.type,
            number=data.number,
            issuing_authority=data.issuing_authority,
            issue_date=data.issue_date,
            expiry_date=data.expiry_date,
            verified=data.verified,
            created_at=now,
            updated_at=now
        )
    )

    return await database.fetch_one(
        UserDocument.__table__.select().where(UserDocument.id == doc_id)
    )


@user_documents_router.get("/documents", response_model=List[DocumentResponse])
async def get_documents(
    current_user: AuthUser = Depends(get_current_user)
):
    results = await database.fetch_all(
        UserDocument.__table__.select()
        .where(UserDocument.user_id == current_user.id)
        .order_by(UserDocument.created_at.desc())
    )
    return results
