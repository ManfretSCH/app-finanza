"""Esquemas de transacciones (RF-002)."""

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import TipoMovimiento
from app.schemas.category import CategoryOut


class TransactionCreate(BaseModel):
    account_id: int
    category_id: int
    tipo: TipoMovimiento
    monto: Decimal = Field(gt=0, decimal_places=2, description="Siempre positivo")
    fecha: date
    descripcion: str | None = Field(default=None, max_length=255)
    etiquetas: str | None = Field(default=None, max_length=255)


class TransactionUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    tipo: TipoMovimiento | None = None
    monto: Decimal | None = Field(default=None, gt=0)
    fecha: date | None = None
    descripcion: str | None = Field(default=None, max_length=255)
    etiquetas: str | None = Field(default=None, max_length=255)


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    account_id: int
    category_id: int
    tipo: TipoMovimiento
    monto: Decimal
    fecha: date
    descripcion: str | None
    etiquetas: str | None
    categoria: CategoryOut | None = Field(default=None, validation_alias="category")


class TransactionPage(BaseModel):
    """Listado paginado: la app movil no descarga todo el historial de una (RNF-001)."""

    total: int
    items: list[TransactionOut]
