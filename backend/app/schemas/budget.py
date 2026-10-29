"""Esquemas de presupuestos (RF-004)."""
from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.category import CategoryOut

class BudgetCreate(BaseModel):
    category_id: int
    anio: int = Field(ge=2000, le=2100)
    mes: int = Field(ge=1, le=12)
    limite: Decimal = Field(gt=0, decimal_places=2)

class BudgetUpdate(BaseModel):
    limite: Decimal = Field(gt=0, decimal_places=2)

class BudgetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    category_id: int
    anio: int
    mes: int
    limite: Decimal
    gastado: Decimal = Decimal("0")
    porcentaje: float = 0
    alerta: str | None = None
    categoria: CategoryOut | None = None
