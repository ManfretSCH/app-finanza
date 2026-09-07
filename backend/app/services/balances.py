"""Calculo de saldos de cuentas (RF-001).

El saldo no se guarda como columna: se calcula sumando los movimientos.
Asi el saldo y el historial de transacciones nunca pueden quedar desfasados.
"""

from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models import Account, Transaction
from app.models.enums import TipoMovimiento


def _suma_movimientos():
    """Expresion SQL que suma ingresos y resta gastos."""
    return func.coalesce(
        func.sum(
            case(
                (Transaction.tipo == TipoMovimiento.INGRESO, Transaction.monto),
                else_=-Transaction.monto,
            )
        ),
        0,
    )


def saldo_de_cuenta(db: Session, account: Account) -> Decimal:
    """saldo_inicial + ingresos - gastos de esa cuenta."""
    movimientos = db.execute(
        select(_suma_movimientos()).where(Transaction.account_id == account.id)
    ).scalar_one()
    return Decimal(account.saldo_inicial) + Decimal(movimientos)


def saldos_por_cuenta(db: Session, user_id: int) -> dict[int, Decimal]:
    """Saldo de todas las cuentas del usuario en una sola consulta.

    Se hace agrupado y no cuenta por cuenta para no disparar N consultas al listar (RNF-001).
    """
    filas = db.execute(
        select(Account.id, Account.saldo_inicial, _suma_movimientos())
        .outerjoin(Transaction, Transaction.account_id == Account.id)
        .where(Account.user_id == user_id)
        .group_by(Account.id, Account.saldo_inicial)
    ).all()
    return {
        account_id: Decimal(saldo_inicial) + Decimal(movimientos)
        for account_id, saldo_inicial, movimientos in filas
    }
