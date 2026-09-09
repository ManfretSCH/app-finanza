"""Generacion de los movimientos a partir de los gastos fijos.

Un gasto fijo se carga una vez y cada mes tiene que aparecer un movimiento
real. No hay ningun proceso corriendo en el servidor que los cree, asi que se
generan cuando el usuario abre la app: se recorren los meses que pasaron desde
la ultima vez y se crea lo que falte.

Que sean transacciones de verdad y no algo aparte es lo que hace que el saldo,
los filtros, los informes y la exportacion funcionen sin saber nada de esto.
"""

from calendar import monthrange
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import RecurringMovement, Transaction


def hoy() -> date:
    # date.today() a proposito: lo que importa es el dia del calendario del
    # usuario, no el de UTC.
    return date.today()  # noqa: DTZ011


def fecha_del_mes(anio: int, mes: int, dia_pedido: int) -> date:
    """Fecha del movimiento en ese mes.

    Si el mes no llega al dia pedido se usa el ultimo dia: un alquiler que vence
    el 31 tiene que caer el 28 en febrero, no saltearse el mes.
    """
    ultimo_dia = monthrange(anio, mes)[1]
    return date(anio, mes, min(dia_pedido, ultimo_dia))


def _meses_entre(desde: date, hasta: date) -> list[tuple[int, int]]:
    """Todos los pares (anio, mes) desde uno hasta el otro, ambos incluidos."""
    meses = []
    anio, mes = desde.year, desde.month
    while (anio, mes) <= (hasta.year, hasta.month):
        meses.append((anio, mes))
        mes += 1
        if mes == 13:
            anio, mes = anio + 1, 1
    return meses


def ocurrencias_previstas(fijo: RecurringMovement, hasta: date) -> list[date]:
    """Fechas en las que este gasto fijo deberia haber generado un movimiento."""
    if not fijo.activo:
        return []

    limite = hasta
    if fijo.fecha_fin and fijo.fecha_fin < limite:
        limite = fijo.fecha_fin
    if limite < fijo.fecha_inicio:
        return []

    fechas = []
    for anio, mes in _meses_entre(fijo.fecha_inicio, limite):
        fecha = fecha_del_mes(anio, mes, fijo.dia_del_mes)
        # El primer y el ultimo mes pueden quedar fuera del rango por el dia.
        if fijo.fecha_inicio <= fecha <= limite:
            fechas.append(fecha)
    return fechas


def generar_pendientes(db: Session, user_id: int, hasta: date | None = None) -> int:
    """Crea los movimientos que faltan de todos los gastos fijos del usuario.

    Devuelve cuantos creo. Es idempotente: llamarla dos veces seguidas no
    duplica nada, porque se compara contra lo que ya se genero de cada plantilla.
    """
    limite = hasta or hoy()

    fijos = db.scalars(
        select(RecurringMovement).where(
            RecurringMovement.user_id == user_id,
            RecurringMovement.activo.is_(True),
        )
    ).all()

    creados = 0
    for fijo in fijos:
        # Una sola consulta por plantilla en lugar de una por mes.
        ya_generadas = set(
            db.scalars(
                select(Transaction.fecha).where(Transaction.recurring_id == fijo.id)
            ).all()
        )
        for fecha in ocurrencias_previstas(fijo, limite):
            if fecha in ya_generadas:
                continue
            db.add(
                Transaction(
                    user_id=fijo.user_id,
                    account_id=fijo.account_id,
                    category_id=fijo.category_id,
                    recurring_id=fijo.id,
                    tipo=fijo.tipo,
                    monto=fijo.monto,
                    descripcion=fijo.descripcion,
                    fecha=fecha,
                )
            )
            creados += 1

    if creados:
        db.commit()
    return creados
