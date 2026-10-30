"""Esquemas de metas de ahorro (RF-005)."""
from datetime import date
from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field
from app.models.enums import EstadoMeta

class SavingsGoalCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=120)
    descripcion: str | None = Field(default=None, max_length=255)
    monto_objetivo: Decimal = Field(gt=0, decimal_places=2)
    monto_actual: Decimal = Field(default=Decimal("0"), ge=0, decimal_places=2)
    fecha_objetivo: date

class SavingsGoalUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=120)
    descripcion: str | None = Field(default=None, max_length=255)
    monto_objetivo: Decimal | None = Field(default=None, gt=0, decimal_places=2)
    monto_actual: Decimal | None = Field(default=None, ge=0, decimal_places=2)
    fecha_objetivo: date | None = None
    estado: EstadoMeta | None = None

class SavingsGoalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    descripcion: str | None
    monto_objetivo: Decimal
    monto_actual: Decimal
    fecha_objetivo: date
    estado: EstadoMeta
    progreso: float = 0
