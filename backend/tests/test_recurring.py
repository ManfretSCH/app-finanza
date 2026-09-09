"""Pruebas de los movimientos fijos.

Lo delicado acá son las fechas: meses que no llegan al día pedido, plantillas
que empiezan a mitad de camino, y no duplicar lo ya generado.
"""

from datetime import date

import pytest

from app.models import RecurringMovement
from app.models.enums import TipoMovimiento
from app.services.recurrentes import fecha_del_mes, ocurrencias_previstas
from tests.conftest import crear_cuenta, registrar_usuario


@pytest.fixture
def base(client, auth):
    """Una cuenta y las categorías, que es lo mínimo para cargar un gasto fijo."""
    cuenta = crear_cuenta(client, auth, nombre="Caja", saldo="0.00")
    categorias = client.get("/api/v1/categories", headers=auth).json()
    return {
        "cuenta": cuenta,
        "gasto": next(c for c in categorias if c["nombre"] == "Vivienda"),
        "ingreso": next(c for c in categorias if c["nombre"] == "Salario"),
    }


def alta(client, auth, base, **extra):
    cuerpo = {
        "account_id": base["cuenta"]["id"],
        "category_id": base["gasto"]["id"],
        "tipo": "gasto",
        "monto": "1200000.00",
        "dia_del_mes": 1,
        "fecha_inicio": "2026-07-01",
        "descripcion": "Alquiler",
    }
    cuerpo.update(extra)
    r = client.post("/api/v1/recurring", json=cuerpo, headers=auth)
    assert r.status_code == 201, r.text
    return r.json()


# --------------------------------------------------- calculo de fechas


def test_un_mes_corto_usa_su_ultimo_dia():
    """Un alquiler que vence el 31 no puede saltearse febrero."""
    assert fecha_del_mes(2026, 2, 31) == date(2026, 2, 28)
    assert fecha_del_mes(2028, 2, 31) == date(2028, 2, 29)  # bisiesto
    assert fecha_del_mes(2026, 4, 31) == date(2026, 4, 30)
    assert fecha_del_mes(2026, 3, 15) == date(2026, 3, 15)


def test_las_ocurrencias_respetan_inicio_y_fin():
    fijo = RecurringMovement(
        user_id=1, account_id=1, category_id=1, tipo=TipoMovimiento.GASTO,
        monto=1000, dia_del_mes=10,
        fecha_inicio=date(2026, 7, 1), fecha_fin=date(2026, 9, 30), activo=True,
    )
    assert ocurrencias_previstas(fijo, date(2026, 12, 31)) == [
        date(2026, 7, 10), date(2026, 8, 10), date(2026, 9, 10)
    ]


def test_no_se_generan_ocurrencias_futuras():
    fijo = RecurringMovement(
        user_id=1, account_id=1, category_id=1, tipo=TipoMovimiento.GASTO,
        monto=1000, dia_del_mes=25, fecha_inicio=date(2026, 7, 1), activo=True,
    )
    # Al 10 de septiembre, el 25 de septiembre todavia no llego.
    assert ocurrencias_previstas(fijo, date(2026, 9, 10)) == [
        date(2026, 7, 25), date(2026, 8, 25)
    ]


def test_uno_desactivado_no_genera_nada():
    fijo = RecurringMovement(
        user_id=1, account_id=1, category_id=1, tipo=TipoMovimiento.GASTO,
        monto=1000, dia_del_mes=1, fecha_inicio=date(2026, 1, 1), activo=False,
    )
    assert ocurrencias_previstas(fijo, date(2026, 12, 31)) == []


# --------------------------------------------------- a traves de la API


def test_al_crearlo_se_generan_los_meses_que_ya_pasaron(client, auth, base):
    """Se carga el alquiler desde julio y aparecen los meses corridos."""
    alta(client, auth, base)

    movimientos = client.get("/api/v1/transactions?limite=200", headers=auth).json()["items"]
    generados = [m for m in movimientos if m["recurring_id"] is not None]

    assert len(generados) >= 2  # julio y agosto como minimo
    assert all(float(m["monto"]) == 1200000.0 for m in generados)
    assert {m["fecha"][:7] for m in generados} >= {"2026-07", "2026-08"}


def test_ponerse_al_dia_no_duplica(client, auth, base):
    """Es idempotente: llamarla de mas no crea nada."""
    alta(client, auth, base)
    antes = client.get("/api/v1/transactions?limite=200", headers=auth).json()["total"]

    r = client.post("/api/v1/recurring/run", headers=auth)
    assert r.status_code == 200
    assert r.json()["generados"] == 0

    assert client.get("/api/v1/transactions?limite=200", headers=auth).json()["total"] == antes


def test_los_generados_afectan_el_saldo_como_cualquier_movimiento(client, auth, base):
    """Son transacciones de verdad, no algo aparte."""
    alta(client, auth, base)

    saldo = float(
        client.get(f"/api/v1/accounts/{base['cuenta']['id']}", headers=auth).json()["saldo_actual"]
    )
    cantidad = len(
        [
            m
            for m in client.get("/api/v1/transactions?limite=200", headers=auth).json()["items"]
            if m["recurring_id"] is not None
        ]
    )
    assert saldo == -1200000.0 * cantidad


def test_borrar_la_plantilla_conserva_lo_ya_generado(client, auth, base):
    """Esa plata ya se gasto: borrarla cambiaria meses cerrados."""
    fijo = alta(client, auth, base)
    antes = client.get("/api/v1/transactions?limite=200", headers=auth).json()["total"]

    assert client.delete(f"/api/v1/recurring/{fijo['id']}", headers=auth).status_code == 204

    despues = client.get("/api/v1/transactions?limite=200", headers=auth).json()
    assert despues["total"] == antes
    # Y ya no queda ninguna plantilla activa.
    assert client.get("/api/v1/recurring", headers=auth).json() == []


def test_desactivarlo_frena_los_meses_siguientes(client, auth, base):
    fijo = alta(client, auth, base)
    client.patch(f"/api/v1/recurring/{fijo['id']}", json={"activo": False}, headers=auth)

    assert client.post("/api/v1/recurring/run", headers=auth).json()["generados"] == 0


def test_tambien_sirve_para_un_ingreso_fijo(client, auth, base):
    """El sueldo es el caso mas comun de ingreso fijo."""
    fijo = alta(
        client, auth, base,
        tipo="ingreso", category_id=base["ingreso"]["id"],
        monto="4500000.00", descripcion="Sueldo",
    )
    assert fijo["tipo"] == "ingreso"

    generados = [
        m
        for m in client.get("/api/v1/transactions?limite=200", headers=auth).json()["items"]
        if m["recurring_id"] == fijo["id"]
    ]
    assert generados
    assert all(m["tipo"] == "ingreso" for m in generados)


def test_la_fecha_de_fin_no_puede_ser_anterior_al_inicio(client, auth, base):
    r = client.post(
        "/api/v1/recurring",
        json={
            "account_id": base["cuenta"]["id"], "category_id": base["gasto"]["id"],
            "tipo": "gasto", "monto": "1000.00", "dia_del_mes": 1,
            "fecha_inicio": "2026-09-01", "fecha_fin": "2026-08-01",
        },
        headers=auth,
    )
    assert r.status_code == 422


def test_un_usuario_no_ve_ni_toca_los_de_otro(client, auth, base):
    """Aislamiento (RNF-002)."""
    fijo = alta(client, auth, base)
    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")

    assert client.get("/api/v1/recurring", headers=otro).json() == []
    assert client.patch(
        f"/api/v1/recurring/{fijo['id']}", json={"monto": "1.00"}, headers=otro
    ).status_code == 404
    assert client.delete(f"/api/v1/recurring/{fijo['id']}", headers=otro).status_code == 404
    # Y ponerse al dia no le genera nada de otro.
    assert client.post("/api/v1/recurring/run", headers=otro).json()["generados"] == 0
