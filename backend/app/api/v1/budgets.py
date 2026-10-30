"""Presupuestos mensuales y alertas de consumo (RF-004)."""
from datetime import date
from decimal import Decimal
from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload
from app.api.deps import CurrentUser, DbSession
from app.models import Budget, Category, Transaction
from app.models.enums import TipoMovimiento
from app.schemas.budget import BudgetCreate, BudgetOut, BudgetUpdate

router = APIRouter(prefix="/budgets", tags=["presupuestos"])

def _periodo(mes: int | None, anio: int | None) -> tuple[int, int]:
    hoy = date.today()
    return mes or hoy.month, anio or hoy.year

def _out(db: DbSession, p: Budget) -> BudgetOut:
    desde = date(p.anio, p.mes, 1)
    hasta = date(p.anio + (p.mes == 12), p.mes % 12 + 1, 1)
    gastado = db.scalar(select(func.coalesce(func.sum(Transaction.monto), 0)).where(
        Transaction.user_id == p.user_id, Transaction.category_id == p.category_id,
        Transaction.tipo == TipoMovimiento.GASTO, Transaction.fecha >= desde, Transaction.fecha < hasta
    )) or Decimal("0")
    porcentaje = float(gastado / p.limite * 100) if p.limite else 0
    alerta = "limite" if porcentaje >= 100 else ("atencion" if porcentaje >= 80 else None)
    return BudgetOut(id=p.id, category_id=p.category_id, anio=p.anio, mes=p.mes,
        limite=p.limite, gastado=gastado, porcentaje=round(porcentaje, 2), alerta=alerta,
        categoria=p.category)

def _categoria_gasto(db: DbSession, usuario: CurrentUser, category_id: int) -> Category:
    c = db.get(Category, category_id)
    if c is None or (c.user_id is not None and c.user_id != usuario.id) or c.tipo != TipoMovimiento.GASTO:
        raise HTTPException(status_code=404, detail="La categoría de gasto indicada no existe")
    return c

@router.get("", response_model=list[BudgetOut])
def listar(usuario: CurrentUser, db: DbSession, mes: int | None = Query(default=None, ge=1, le=12), anio: int | None = Query(default=None, ge=2000, le=2100)) -> list[BudgetOut]:
    mes, anio = _periodo(mes, anio)
    rows = db.scalars(select(Budget).where(Budget.user_id == usuario.id, Budget.mes == mes, Budget.anio == anio).options(selectinload(Budget.category)).order_by(Budget.id)).all()
    return [_out(db, p) for p in rows]

@router.post("", response_model=BudgetOut, status_code=status.HTTP_201_CREATED)
def crear(datos: BudgetCreate, usuario: CurrentUser, db: DbSession) -> BudgetOut:
    _categoria_gasto(db, usuario, datos.category_id)
    existente = db.scalar(select(Budget).where(Budget.user_id == usuario.id, Budget.category_id == datos.category_id, Budget.mes == datos.mes, Budget.anio == datos.anio))
    if existente:
        raise HTTPException(status_code=409, detail="Ya existe un presupuesto para esa categoría y período")
    p = Budget(user_id=usuario.id, **datos.model_dump())
    db.add(p); db.commit(); db.refresh(p)
    p.category = db.get(Category, p.category_id)
    return _out(db, p)

@router.patch("/{budget_id}", response_model=BudgetOut)
def editar(budget_id: int, datos: BudgetUpdate, usuario: CurrentUser, db: DbSession) -> BudgetOut:
    p = db.scalar(select(Budget).where(Budget.id == budget_id, Budget.user_id == usuario.id).options(selectinload(Budget.category)))
    if p is None: raise HTTPException(status_code=404, detail="Presupuesto no encontrado")
    p.limite = datos.limite
    db.commit(); db.refresh(p)
    return _out(db, p)

@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(budget_id: int, usuario: CurrentUser, db: DbSession) -> None:
    p = db.scalar(select(Budget).where(Budget.id == budget_id, Budget.user_id == usuario.id))
    if p is None: raise HTTPException(status_code=404, detail="Presupuesto no encontrado")
    db.delete(p); db.commit()
