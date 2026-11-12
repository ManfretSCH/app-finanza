"""Esquemas de presupuestos (RF-004)."""

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.category import CategoryOut

# "atencion" al llegar al 80 % del limite, "limite" al llegar al 100 %.
Alerta = Literal["atencion", "limite"]


class BudgetCreate(BaseModel):
    category_id: int
    anio: int = Field(ge=2000, le=2100)
    mes: int = Field(ge=1, le=12)
    limite: Decimal = Field(gt=0, decimal_places=2)


class BudgetUpdate(BaseModel):
    limite: Decimal = Field(gt=0, decimal_places=2)


class CopiarPresupuestos(BaseModel):
    """Mes al que se copian los presupuestos del mes anterior."""

    anio: int = Field(ge=2000, le=2100)
    mes: int = Field(ge=1, le=12)


class ResultadoCopia(BaseModel):
    copiados: int


class BudgetOut(BaseModel):
    id: int
    category_id: int
    anio: int
    mes: int
    limite: Decimal
    # Lo gastado en la categoria ese mes, calculado a partir de los movimientos.
    gastado: Decimal
    # Puede ser negativo: es cuanto se paso del limite.
    disponible: Decimal
    porcentaje: float
    alerta: Alerta | None
    categoria: CategoryOut
