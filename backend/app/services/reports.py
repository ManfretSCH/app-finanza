"""Calculos de los informes (RF-006).

Todo se resuelve con agregaciones en la base y no trayendo las transacciones
a memoria: la app movil solo recibe los numeros ya calculados (RNF-001).
"""

from calendar import monthrange
from datetime import date
from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models import Category, Transaction
from app.models.enums import TipoMovimiento

CERO = Decimal("0.00")


def rango_del_mes(mes: int, anio: int) -> tuple[date, date]:
    """Primer y ultimo dia del mes."""
    ultimo_dia = monthrange(anio, mes)[1]
    return date(anio, mes, 1), date(anio, mes, ultimo_dia)


def dias_a_promediar(mes: int, anio: int, hoy: date | None = None) -> int:
    """Cuantos dias se usan para el promedio diario.

    Si el mes todavia esta en curso se usan los dias transcurridos, no los 30 o 31
    completos: si no, a principio de mes el promedio saldria absurdamente bajo.
    """
    # date.today() a proposito: el mes en curso es el del calendario local del
    # usuario, no el de UTC. Con zona horaria el informe cambiaria de mes a
    # destiempo para quien lo mira.
    hoy = hoy or date.today()  # noqa: DTZ011
    if (anio, mes) == (hoy.year, hoy.month):
        return hoy.day
    return monthrange(anio, mes)[1]


def _totales(db: Session, user_id: int, desde: date, hasta: date) -> tuple[Decimal, Decimal]:
    """Suma de ingresos y de gastos del periodo."""
    fila = db.execute(
        select(
            func.coalesce(
                func.sum(
                    case((Transaction.tipo == TipoMovimiento.INGRESO, Transaction.monto), else_=0)
                ),
                0,
            ),
            func.coalesce(
                func.sum(
                    case((Transaction.tipo == TipoMovimiento.GASTO, Transaction.monto), else_=0)
                ),
                0,
            ),
        ).where(
            Transaction.user_id == user_id,
            Transaction.fecha >= desde,
            Transaction.fecha <= hasta,
        )
    ).one()
    return Decimal(fila[0]), Decimal(fila[1])


def resumen_mensual(db: Session, user_id: int, mes: int, anio: int) -> dict:
    """Ingresos, gastos, balance y promedio de gasto por dia."""
    desde, hasta = rango_del_mes(mes, anio)
    ingresos, gastos = _totales(db, user_id, desde, hasta)
    dias = dias_a_promediar(mes, anio)

    cantidad = db.scalar(
        select(func.count(Transaction.id)).where(
            Transaction.user_id == user_id,
            Transaction.fecha >= desde,
            Transaction.fecha <= hasta,
        )
    ) or 0

    return {
        "mes": mes,
        "anio": anio,
        "ingresos": ingresos,
        "gastos": gastos,
        "balance": ingresos - gastos,
        "promedio_diario_gasto": (gastos / dias).quantize(Decimal("0.01")) if dias else CERO,
        "dias_considerados": dias,
        "cantidad_movimientos": cantidad,
    }


def por_categoria(
    db: Session, user_id: int, tipo: TipoMovimiento, mes: int, anio: int
) -> list[dict]:
    """En que se va la plata: total por categoria, de mayor a menor.

    El porcentaje se calcula sobre el total del periodo, asi la app no tiene que
    hacer cuentas para dibujar la torta.
    """
    desde, hasta = rango_del_mes(mes, anio)

    filas = db.execute(
        select(
            Category,
            func.sum(Transaction.monto),
            func.count(Transaction.id),
        )
        .join(Transaction, Transaction.category_id == Category.id)
        .where(
            Transaction.user_id == user_id,
            Transaction.tipo == tipo,
            Transaction.fecha >= desde,
            Transaction.fecha <= hasta,
        )
        .group_by(Category.id)
        .order_by(func.sum(Transaction.monto).desc())
    ).all()

    total = sum((Decimal(f[1]) for f in filas), CERO)

    return [
        {
            "categoria": categoria,
            "total": Decimal(monto),
            "cantidad": cantidad,
            "porcentaje": (
                float((Decimal(monto) / total * 100).quantize(Decimal("0.1"))) if total else 0.0
            ),
        }
        for categoria, monto, cantidad in filas
    ]


def por_dia(db: Session, user_id: int, mes: int, anio: int) -> list[dict]:
    """Ingresos y gastos de cada dia del mes.

    Se devuelven todos los dias, incluso los que no tuvieron movimientos, para que
    el grafico de la app quede continuo y no con huecos.
    """
    desde, hasta = rango_del_mes(mes, anio)

    filas = db.execute(
        select(
            Transaction.fecha,
            func.coalesce(
                func.sum(
                    case((Transaction.tipo == TipoMovimiento.INGRESO, Transaction.monto), else_=0)
                ),
                0,
            ),
            func.coalesce(
                func.sum(
                    case((Transaction.tipo == TipoMovimiento.GASTO, Transaction.monto), else_=0)
                ),
                0,
            ),
        )
        .where(
            Transaction.user_id == user_id,
            Transaction.fecha >= desde,
            Transaction.fecha <= hasta,
        )
        .group_by(Transaction.fecha)
    ).all()

    movimientos = {f[0]: (Decimal(f[1]), Decimal(f[2])) for f in filas}

    resultado = []
    for numero_dia in range(1, hasta.day + 1):
        dia = date(anio, mes, numero_dia)
        ingresos, gastos = movimientos.get(dia, (CERO, CERO))
        resultado.append({"fecha": dia, "ingresos": ingresos, "gastos": gastos})
    return resultado


def por_mes(db: Session, user_id: int, anio: int) -> list[dict]:
    """Tendencia del ano: ingresos, gastos y balance de cada mes."""
    filas = db.execute(
        select(
            func.extract("month", Transaction.fecha).label("mes"),
            func.coalesce(
                func.sum(
                    case((Transaction.tipo == TipoMovimiento.INGRESO, Transaction.monto), else_=0)
                ),
                0,
            ),
            func.coalesce(
                func.sum(
                    case((Transaction.tipo == TipoMovimiento.GASTO, Transaction.monto), else_=0)
                ),
                0,
            ),
        )
        .where(
            Transaction.user_id == user_id,
            Transaction.fecha >= date(anio, 1, 1),
            Transaction.fecha <= date(anio, 12, 31),
        )
        .group_by("mes")
    ).all()

    movimientos = {int(f[0]): (Decimal(f[1]), Decimal(f[2])) for f in filas}

    resultado = []
    for mes in range(1, 13):
        ingresos, gastos = movimientos.get(mes, (CERO, CERO))
        resultado.append(
            {"mes": mes, "ingresos": ingresos, "gastos": gastos, "balance": ingresos - gastos}
        )
    return resultado
