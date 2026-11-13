"""Esquemas de metas de ahorro (RF-005)."""

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import EstadoMeta


class SavingsGoalCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=120)
    descripcion: str | None = Field(default=None, max_length=255)
    monto_objetivo: Decimal = Field(gt=0, decimal_places=2)
    monto_actual: Decimal = Field(default=Decimal(0), ge=0, decimal_places=2)
    fecha_objetivo: date


class SavingsGoalUpdate(BaseModel):
    """Todos los campos son opcionales: se cambia solo lo que se manda.

    El estado solo se puede pasar a "cancelada" o volver a "activa". Si una meta
    esta completada o no lo decide el servidor comparando lo ahorrado con el
    objetivo, para que nunca diga "completada" con la mitad juntada.
    """

    nombre: str | None = Field(default=None, min_length=1, max_length=120)
    descripcion: str | None = Field(default=None, max_length=255)
    monto_objetivo: Decimal | None = Field(default=None, gt=0, decimal_places=2)
    monto_actual: Decimal | None = Field(default=None, ge=0, decimal_places=2)
    fecha_objetivo: date | None = None
    estado: EstadoMeta | None = None


class AporteMeta(BaseModel):
    """Plata que se suma a lo ya ahorrado."""

    monto: Decimal = Field(gt=0, decimal_places=2)


class SavingsGoalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    descripcion: str | None
    monto_objetivo: Decimal
    monto_actual: Decimal
    fecha_objetivo: date
    estado: EstadoMeta
    # Porcentaje de lo ahorrado sobre el objetivo, de 0 a 100.
    progreso: float
