"""Esquemas de cuentas (RF-001)."""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.account_type import AccountTypeOut


class AccountCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=120)
    account_type_id: int
    saldo_inicial: Decimal = Field(default=Decimal("0.00"), decimal_places=2)
    moneda: str = Field(default="PYG", min_length=3, max_length=3)


class AccountUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=120)
    account_type_id: int | None = None
    saldo_inicial: Decimal | None = None
    moneda: str | None = Field(default=None, min_length=3, max_length=3)
    activa: bool | None = None


class AccountOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    account_type_id: int
    saldo_inicial: Decimal
    moneda: str
    activa: bool
    tipo: AccountTypeOut | None = None


class AccountWithBalance(AccountOut):
    """Cuenta con el saldo ya calculado (saldo_inicial + ingresos - gastos)."""

    saldo_actual: Decimal
