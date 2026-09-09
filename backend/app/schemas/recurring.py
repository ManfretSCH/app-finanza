"""Esquemas de los movimientos fijos."""

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import TipoMovimiento
from app.schemas.category import CategoryOut


class RecurringCreate(BaseModel):
    account_id: int
    category_id: int
    tipo: TipoMovimiento
    monto: Decimal = Field(gt=0, decimal_places=2)
    dia_del_mes: int = Field(ge=1, le=31, description="Si el mes no llega, se usa el ultimo dia")
    fecha_inicio: date
    fecha_fin: date | None = None
    descripcion: str | None = Field(default=None, max_length=255)

    @model_validator(mode="after")
    def _fin_despues_del_inicio(self) -> "RecurringCreate":
        if self.fecha_fin and self.fecha_fin < self.fecha_inicio:
            raise ValueError("La fecha de fin no puede ser anterior a la de inicio")
        return self


class RecurringUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    tipo: TipoMovimiento | None = None
    monto: Decimal | None = Field(default=None, gt=0)
    dia_del_mes: int | None = Field(default=None, ge=1, le=31)
    fecha_inicio: date | None = None
    fecha_fin: date | None = None
    descripcion: str | None = Field(default=None, max_length=255)
    activo: bool | None = None


class RecurringOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    account_id: int
    category_id: int
    tipo: TipoMovimiento
    monto: Decimal
    dia_del_mes: int
    fecha_inicio: date
    fecha_fin: date | None
    descripcion: str | None
    activo: bool
    categoria: CategoryOut | None = Field(default=None, validation_alias="category")


class ResultadoGeneracion(BaseModel):
    """Cuantos movimientos se crearon al ponerse al dia."""

    generados: int
