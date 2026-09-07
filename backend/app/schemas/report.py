"""Esquemas de los informes (RF-006)."""

from datetime import date
from decimal import Decimal

from pydantic import BaseModel

from app.schemas.category import CategoryOut


class ResumenMensual(BaseModel):
    """Los numeros gruesos del mes."""

    mes: int
    anio: int
    ingresos: Decimal
    gastos: Decimal
    balance: Decimal
    promedio_diario_gasto: Decimal
    dias_considerados: int
    cantidad_movimientos: int


class LineaCategoria(BaseModel):
    """Cuanto se fue en una categoria y que parte del total representa."""

    categoria: CategoryOut
    total: Decimal
    cantidad: int
    porcentaje: float


class LineaDia(BaseModel):
    fecha: date
    ingresos: Decimal
    gastos: Decimal


class LineaMes(BaseModel):
    mes: int
    ingresos: Decimal
    gastos: Decimal
    balance: Decimal
