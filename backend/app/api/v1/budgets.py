"""Presupuestos mensuales por categoria y sus alertas (RF-004).

Casos de uso del diagrama 04: Crear presupuesto, Editar presupuesto, Ver
presupuestos, Recibir alertas, Ver progreso.
"""

from datetime import date

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.models import Budget, Category
from app.models.enums import TipoMovimiento
from app.schemas.budget import (
    BudgetCreate,
    BudgetOut,
    BudgetUpdate,
    CopiarPresupuestos,
    ResultadoCopia,
)
from app.services import presupuestos
from app.services.reports import CERO

router = APIRouter(prefix="/budgets", tags=["presupuestos"])


def _categoria_de_gasto(db: DbSession, usuario: CurrentUser, category_id: int) -> Category:
    """La categoria tiene que estar al alcance del usuario y ser de gasto."""
    categoria = db.get(Category, category_id)
    if categoria is None or (categoria.user_id is not None and categoria.user_id != usuario.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="La categoría indicada no existe"
        )
    if categoria.tipo != TipoMovimiento.GASTO:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Los presupuestos son para categorías de gasto",
        )
    return categoria


def _propio(db: DbSession, usuario: CurrentUser, budget_id: int) -> Budget:
    presupuesto = db.scalar(
        select(Budget)
        .where(Budget.id == budget_id, Budget.user_id == usuario.id)
        .options(selectinload(Budget.category))
    )
    if presupuesto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Presupuesto no encontrado"
        )
    return presupuesto


def _salida(db: DbSession, presupuesto: Budget) -> BudgetOut:
    gastado = presupuestos.gastado_por_categoria(
        db, presupuesto.user_id, presupuesto.mes, presupuesto.anio
    )
    return presupuestos.armar_salida(presupuesto, gastado.get(presupuesto.category_id, CERO))


@router.get("", response_model=list[BudgetOut])
def listar(
    usuario: CurrentUser,
    db: DbSession,
    mes: int | None = Query(default=None, ge=1, le=12),
    anio: int | None = Query(default=None, ge=2000, le=2100),
) -> list[BudgetOut]:
    """Presupuestos del mes con lo gastado, el porcentaje usado y la alerta que corresponda.

    Sin mes ni año devuelve los del mes en curso.
    """
    # date.today() a proposito, igual que en los informes: el mes en curso es
    # el del calendario local del usuario, no el de UTC.
    hoy = date.today()  # noqa: DTZ011
    mes, anio = mes or hoy.month, anio or hoy.year

    filas = db.scalars(
        select(Budget)
        .join(Budget.category)
        .where(Budget.user_id == usuario.id, Budget.mes == mes, Budget.anio == anio)
        .options(selectinload(Budget.category))
        .order_by(Category.nombre)
    ).all()
    gastado = presupuestos.gastado_por_categoria(db, usuario.id, mes, anio)
    return [presupuestos.armar_salida(p, gastado.get(p.category_id, CERO)) for p in filas]


@router.post("", response_model=BudgetOut, status_code=status.HTTP_201_CREATED)
def crear(datos: BudgetCreate, usuario: CurrentUser, db: DbSession) -> BudgetOut:
    _categoria_de_gasto(db, usuario, datos.category_id)
    ya_existe = db.scalar(
        select(Budget.id).where(
            Budget.user_id == usuario.id,
            Budget.category_id == datos.category_id,
            Budget.mes == datos.mes,
            Budget.anio == datos.anio,
        )
    )
    if ya_existe:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Esa categoría ya tiene un presupuesto para ese mes",
        )

    presupuesto = Budget(user_id=usuario.id, **datos.model_dump())
    db.add(presupuesto)
    db.commit()
    db.refresh(presupuesto)
    return _salida(db, presupuesto)


@router.post("/copiar", response_model=ResultadoCopia)
def copiar_mes_anterior(
    datos: CopiarPresupuestos, usuario: CurrentUser, db: DbSession
) -> ResultadoCopia:
    """Repite en el mes indicado los presupuestos del mes anterior."""
    copiados = presupuestos.copiar_del_mes_anterior(db, usuario.id, datos.mes, datos.anio)
    return ResultadoCopia(copiados=copiados)


@router.patch("/{budget_id}", response_model=BudgetOut)
def editar(budget_id: int, datos: BudgetUpdate, usuario: CurrentUser, db: DbSession) -> BudgetOut:
    """Solo se cambia el limite: para otra categoria u otro mes se crea uno nuevo."""
    presupuesto = _propio(db, usuario, budget_id)
    presupuesto.limite = datos.limite
    db.commit()
    db.refresh(presupuesto)
    return _salida(db, presupuesto)


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(budget_id: int, usuario: CurrentUser, db: DbSession) -> None:
    presupuesto = _propio(db, usuario, budget_id)
    db.delete(presupuesto)
    db.commit()
