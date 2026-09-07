"""Gestion de cuentas (RF-001).

Casos de uso del diagrama 02: Crear, Editar, Ver cuentas, Eliminar, Ver saldo.
"""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.models import Account, AccountType
from app.schemas.account import AccountCreate, AccountOut, AccountUpdate, AccountWithBalance
from app.services.balances import saldo_de_cuenta, saldos_por_cuenta

router = APIRouter(prefix="/accounts", tags=["cuentas"])


def _cuenta_del_usuario(db: DbSession, usuario: CurrentUser, account_id: int) -> Account:
    """Busca la cuenta verificando que sea del usuario del token.

    Se devuelve 404 y no 403 a proposito: un usuario no deberia poder deducir
    que cuentas existen de otros.
    """
    cuenta = db.scalar(
        select(Account).where(Account.id == account_id, Account.user_id == usuario.id)
    )
    if cuenta is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cuenta no encontrada")
    return cuenta


@router.get("", response_model=list[AccountWithBalance])
def listar_cuentas(
    usuario: CurrentUser, db: DbSession, incluir_inactivas: bool = False
) -> list[AccountWithBalance]:
    """Lista las cuentas con su saldo actual ya calculado."""
    consulta = select(Account).where(Account.user_id == usuario.id).options(
        selectinload(Account.tipo)
    )
    if not incluir_inactivas:
        consulta = consulta.where(Account.activa.is_(True))

    cuentas = db.scalars(consulta.order_by(Account.id)).all()
    saldos = saldos_por_cuenta(db, usuario.id)

    return [
        AccountWithBalance(
            **AccountOut.model_validate(c).model_dump(),
            saldo_actual=saldos.get(c.id, c.saldo_inicial),
        )
        for c in cuentas
    ]


def _validar_tipo(db: DbSession, usuario: CurrentUser, account_type_id: int | None) -> None:
    """El tipo tiene que existir y ser predefinido o del propio usuario."""
    if account_type_id is None:
        return
    tipo = db.get(AccountType, account_type_id)
    if tipo is None or (tipo.user_id is not None and tipo.user_id != usuario.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El tipo de cuenta indicado no existe",
        )


@router.post("", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
def crear_cuenta(datos: AccountCreate, usuario: CurrentUser, db: DbSession) -> Account:
    _validar_tipo(db, usuario, datos.account_type_id)
    cuenta = Account(user_id=usuario.id, **datos.model_dump())
    db.add(cuenta)
    db.commit()
    db.refresh(cuenta)
    return cuenta


@router.get("/{account_id}", response_model=AccountWithBalance)
def ver_cuenta(account_id: int, usuario: CurrentUser, db: DbSession) -> AccountWithBalance:
    cuenta = _cuenta_del_usuario(db, usuario, account_id)
    return AccountWithBalance(
        **AccountOut.model_validate(cuenta).model_dump(),
        saldo_actual=saldo_de_cuenta(db, cuenta),
    )


@router.patch("/{account_id}", response_model=AccountOut)
def editar_cuenta(
    account_id: int, datos: AccountUpdate, usuario: CurrentUser, db: DbSession
) -> Account:
    cuenta = _cuenta_del_usuario(db, usuario, account_id)
    cambios = datos.model_dump(exclude_unset=True)
    _validar_tipo(db, usuario, cambios.get("account_type_id"))
    for campo, valor in cambios.items():
        setattr(cuenta, campo, valor)
    db.commit()
    db.refresh(cuenta)
    return cuenta


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_cuenta(account_id: int, usuario: CurrentUser, db: DbSession) -> None:
    """Elimina la cuenta y sus transacciones.

    Si la cuenta ya tiene movimientos se avisa antes: borrarla se lleva el historial,
    y en la mayoria de los casos lo que el usuario quiere es desactivarla
    (PATCH con activa=false), no perder los datos.
    """
    cuenta = _cuenta_del_usuario(db, usuario, account_id)
    if cuenta.transactions:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"La cuenta tiene {len(cuenta.transactions)} movimientos registrados. "
                "Desactivala en lugar de eliminarla, o borra primero sus movimientos."
            ),
        )
    db.delete(cuenta)
    db.commit()
