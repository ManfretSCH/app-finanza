"""Esquemas de categorias (RF-003)."""

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import TipoMovimiento


class CategoryCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=80)
    tipo: TipoMovimiento
    icono: str = Field(default="category", max_length=40)
    color: str = Field(default="#607D8B", pattern=r"^#[0-9A-Fa-f]{6}$")


class CategoryUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=80)
    icono: str | None = Field(default=None, max_length=40)
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    tipo: TipoMovimiento
    icono: str
    color: str
    es_predefinida: bool
