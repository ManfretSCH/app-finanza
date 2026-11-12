"""Calculos de los presupuestos (RF-004).

Lo gastado en cada categoria se suma en la base con una sola consulta por mes,
no una por presupuesto ni trayendo las transacciones a memoria (RNF-001).
"""

from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Budget, Transaction
from app.models.enums import TipoMovimiento
from app.schemas.budget import Alerta, BudgetOut
from app.schemas.category import CategoryOut
from app.services.reports import rango_del_mes

# Umbrales de aviso del RF-004, en porcentaje del limite.
UMBRAL_ATENCION = 80
UMBRAL_LIMITE = 100


def gastado_por_categoria(db: Session, user_id: int, mes: int, anio: int) -> dict[int, Decimal]:
    """Total de gastos del mes agrupado por categoria."""
    desde, hasta = rango_del_mes(mes, anio)
    filas = db.execute(
        select(Transaction.category_id, func.sum(Transaction.monto))
        .where(
            Transaction.user_id == user_id,
            Transaction.tipo == TipoMovimiento.GASTO,
            Transaction.fecha >= desde,
            Transaction.fecha <= hasta,
        )
        .group_by(Transaction.category_id)
    ).all()
    return {category_id: total for category_id, total in filas}


def alerta_para(gastado: Decimal, limite: Decimal) -> Alerta | None:
    """Que aviso corresponde segun cuanto del limite ya se uso.

    Se compara en Decimal y no con el porcentaje redondeado: con float, un gasto
    de exactamente el 80 % podria quedar en 79,999... y no avisar.
    """
    if gastado * 100 >= limite * UMBRAL_LIMITE:
        return "limite"
    if gastado * 100 >= limite * UMBRAL_ATENCION:
        return "atencion"
    return None


def armar_salida(presupuesto: Budget, gastado: Decimal) -> BudgetOut:
    porcentaje = float(gastado / presupuesto.limite * 100)
    return BudgetOut(
        id=presupuesto.id,
        category_id=presupuesto.category_id,
        anio=presupuesto.anio,
        mes=presupuesto.mes,
        limite=presupuesto.limite,
        gastado=gastado,
        disponible=presupuesto.limite - gastado,
        porcentaje=round(porcentaje, 2),
        alerta=alerta_para(gastado, presupuesto.limite),
        categoria=CategoryOut.model_validate(presupuesto.category, from_attributes=True),
    )


def mes_anterior(mes: int, anio: int) -> tuple[int, int]:
    return (12, anio - 1) if mes == 1 else (mes - 1, anio)


def copiar_del_mes_anterior(db: Session, user_id: int, mes: int, anio: int) -> int:
    """Repite en el mes indicado los limites que se usaron el mes anterior.

    Los presupuestos son por mes, y casi siempre se repiten: sin esto habria que
    volver a cargarlos todos cada primero de mes. Las categorias que ya tienen
    presupuesto en el mes destino no se tocan.
    """
    mes_origen, anio_origen = mes_anterior(mes, anio)
    origen = db.scalars(
        select(Budget).where(
            Budget.user_id == user_id, Budget.mes == mes_origen, Budget.anio == anio_origen
        )
    ).all()
    ya_cargadas = set(
        db.scalars(
            select(Budget.category_id).where(
                Budget.user_id == user_id, Budget.mes == mes, Budget.anio == anio
            )
        ).all()
    )

    nuevos = [
        Budget(
            user_id=user_id, category_id=p.category_id, mes=mes, anio=anio, limite=p.limite
        )
        for p in origen
        if p.category_id not in ya_cargadas
    ]
    db.add_all(nuevos)
    db.commit()
    return len(nuevos)
