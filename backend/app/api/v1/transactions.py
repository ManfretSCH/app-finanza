"""Registro y consulta de movimientos (RF-002).

Casos de uso del diagrama 03: Registrar ingreso, Registrar gasto, Editar,
Ver transacciones, Filtrar por categoria.
"""

from datetime import date

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.models import Account, Category, Transaction
from app.models.enums import TipoMovimiento
from app.schemas.transaction import (
    TransactionCreate,
    TransactionOut,
    TransactionPage,
    TransactionUpdate,
)

router = APIRouter(prefix="/transactions", tags=["transacciones"])


def _validar_referencias(
    db: DbSession, usuario: CurrentUser, account_id: int | None, category_id: int | None
) -> None:
    """Verifica que la cuenta sea del usuario y que la categoria exista y le corresponda.

    Sin esto, alguien podria mandar el id de una cuenta ajena y escribir en ella.
    """
    if account_id is not None:
        cuenta = db.scalar(
            select(Account).where(Account.id == account_id, Account.user_id == usuario.id)
        )
        if cuenta is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="La cuenta indicada no existe"
            )

    if category_id is not None:
        categoria = db.get(Category, category_id)
        if categoria is None or (
            categoria.user_id is not None and categoria.user_id != usuario.id
        ):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="La categoria indicada no existe"
            )


@router.get("", response_model=TransactionPage)
def listar_transacciones(
    usuario: CurrentUser,
    db: DbSession,
    tipo: TipoMovimiento | None = None,
    category_id: int | None = None,
    account_id: int | None = None,
    desde: date | None = None,
    hasta: date | None = None,
    limite: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> TransactionPage:
    """Listado paginado con filtros por tipo, categoria, cuenta y rango de fechas."""
    filtros = [Transaction.user_id == usuario.id]
    if tipo is not None:
        filtros.append(Transaction.tipo == tipo)
    if category_id is not None:
        filtros.append(Transaction.category_id == category_id)
    if account_id is not None:
        filtros.append(Transaction.account_id == account_id)
    if desde is not None:
        filtros.append(Transaction.fecha >= desde)
    if hasta is not None:
        filtros.append(Transaction.fecha <= hasta)

    total = db.scalar(select(func.count(Transaction.id)).where(*filtros)) or 0
    items = db.scalars(
        select(Transaction)
        .where(*filtros)
        .options(selectinload(Transaction.category))  # evita una consulta por fila
        .order_by(Transaction.fecha.desc(), Transaction.id.desc())
        .limit(limite)
        .offset(offset)
    ).all()

    return TransactionPage(total=total, items=[TransactionOut.model_validate(t) for t in items])


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
def registrar_transaccion(
    datos: TransactionCreate, usuario: CurrentUser, db: DbSession
) -> Transaction:
    _validar_referencias(db, usuario, datos.account_id, datos.category_id)

    movimiento = Transaction(user_id=usuario.id, **datos.model_dump())
    db.add(movimiento)
    db.commit()
    db.refresh(movimiento)
    return movimiento


def _transaccion_del_usuario(db: DbSession, usuario: CurrentUser, tx_id: int) -> Transaction:
    movimiento = db.scalar(
        select(Transaction).where(Transaction.id == tx_id, Transaction.user_id == usuario.id)
    )
    if movimiento is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Movimiento no encontrado"
        )
    return movimiento


@router.get("/{tx_id}", response_model=TransactionOut)
def ver_transaccion(tx_id: int, usuario: CurrentUser, db: DbSession) -> Transaction:
    return _transaccion_del_usuario(db, usuario, tx_id)


@router.patch("/{tx_id}", response_model=TransactionOut)
def editar_transaccion(
    tx_id: int, datos: TransactionUpdate, usuario: CurrentUser, db: DbSession
) -> Transaction:
    movimiento = _transaccion_del_usuario(db, usuario, tx_id)
    cambios = datos.model_dump(exclude_unset=True)
    _validar_referencias(db, usuario, cambios.get("account_id"), cambios.get("category_id"))

    for campo, valor in cambios.items():
        setattr(movimiento, campo, valor)
    db.commit()
    db.refresh(movimiento)
    return movimiento


@router.delete("/{tx_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_transaccion(tx_id: int, usuario: CurrentUser, db: DbSession) -> None:
    movimiento = _transaccion_del_usuario(db, usuario, tx_id)
    db.delete(movimiento)
    db.commit()
