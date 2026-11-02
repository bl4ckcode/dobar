from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class DraftCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    creation_key: str = Field(min_length=8, max_length=80, pattern=r"^[A-Za-z0-9_-]+$")


class DraftPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: int = Field(ge=1)
    payload: dict = Field(default_factory=dict)
    steps: dict[str, Literal["unvisited", "in_progress", "complete", "skipped"]] = Field(default_factory=dict)
    bank_account: dict | None = None


class DraftFinalize(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: int = Field(ge=1)
    operation_key: str = Field(min_length=8, max_length=80, pattern=r"^[A-Za-z0-9_-]+$")
