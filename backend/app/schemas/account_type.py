"""Esquemas de tipos de cuenta."""

from pydantic import BaseModel, ConfigDict, Field


class AccountTypeCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=80)
    icono: str = Field(default="account_balance_wallet", max_length=40)


class AccountTypeUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=80)
    icono: str | None = Field(default=None, max_length=40)


class AccountTypeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    icono: str
    es_predefinido: bool
