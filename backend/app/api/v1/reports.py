"""Informes y analisis (RF-006).

Responden las preguntas que se hace alguien mirando sus finanzas:
cuanto entro y salio este mes, cuanto gasto por dia, en que se le va la plata
y de donde viene lo que entra.
"""

from datetime import date

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.models.enums import TipoMovimiento
from app.schemas.report import LineaCategoria, LineaDia, LineaMes, ResumenMensual
from app.services import reports

router = APIRouter(prefix="/reports", tags=["informes"])

MesActual = Query(default=None, ge=1, le=12, description="Por defecto, el mes en curso")
AnioActual = Query(default=None, ge=2000, le=2100, description="Por defecto, el ano en curso")


def _periodo(mes: int | None, anio: int | None) -> tuple[int, int]:
    """Si no se pide un periodo, se usa el mes del calendario local del usuario."""
    hoy = date.today()  # noqa: DTZ011
    return mes or hoy.month, anio or hoy.year


@router.get("/resumen", response_model=ResumenMensual)
def resumen(
    usuario: CurrentUser,
    db: DbSession,
    mes: int | None = MesActual,
    anio: int | None = AnioActual,
) -> ResumenMensual:
    """Ingresos, gastos, balance y promedio de gasto por dia del mes."""
    mes, anio = _periodo(mes, anio)
    return ResumenMensual(**reports.resumen_mensual(db, usuario.id, mes, anio))


@router.get("/por-categoria", response_model=list[LineaCategoria])
def distribucion_por_categoria(
    usuario: CurrentUser,
    db: DbSession,
    tipo: TipoMovimiento = Query(default=TipoMovimiento.GASTO),  # noqa: B008
    mes: int | None = MesActual,
    anio: int | None = AnioActual,
) -> list[LineaCategoria]:
    """En que se va la plata (o de donde viene, con tipo=ingreso)."""
    mes, anio = _periodo(mes, anio)
    return [
        LineaCategoria.model_validate(fila, from_attributes=True)
        for fila in reports.por_categoria(db, usuario.id, tipo, mes, anio)
    ]


@router.get("/por-dia", response_model=list[LineaDia])
def evolucion_diaria(
    usuario: CurrentUser,
    db: DbSession,
    mes: int | None = MesActual,
    anio: int | None = AnioActual,
) -> list[LineaDia]:
    """Cuanto entro y salio cada dia del mes."""
    mes, anio = _periodo(mes, anio)
    return [LineaDia(**fila) for fila in reports.por_dia(db, usuario.id, mes, anio)]


@router.get("/por-mes", response_model=list[LineaMes])
def tendencia_anual(
    usuario: CurrentUser,
    db: DbSession,
    anio: int | None = AnioActual,
) -> list[LineaMes]:
    """Los doce meses del ano, para ver la tendencia."""
    _, anio = _periodo(None, anio)
    return [LineaMes(**fila) for fila in reports.por_mes(db, usuario.id, anio)]
