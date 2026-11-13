"""Pruebas de los presupuestos mensuales (RF-004).

Lo importante acá: que lo gastado salga de los movimientos reales del mes y de
la categoría, que las alertas salten justo en el 80 % y el 100 %, y que nadie
pueda ver ni tocar presupuestos ajenos.
"""

from decimal import Decimal

import pytest

from app.services.presupuestos import alerta_para, mes_anterior
from tests.conftest import crear_cuenta, registrar_usuario

URL = "/api/v1/budgets"


@pytest.fixture
def base(client, auth):
    cuenta = crear_cuenta(client, auth, nombre="Caja", saldo="0.00")
    categorias = client.get("/api/v1/categories", headers=auth).json()
    return {
        "cuenta": cuenta,
        "comida": next(c for c in categorias if c["nombre"] == "Alimentación"),
        "transporte": next(c for c in categorias if c["nombre"] == "Transporte"),
        "salario": next(c for c in categorias if c["nombre"] == "Salario"),
    }


def presupuesto(client, auth, categoria, limite="1000000.00", mes=10, anio=2026):
    r = client.post(
        URL,
        json={"category_id": categoria["id"], "mes": mes, "anio": anio, "limite": limite},
        headers=auth,
    )
    assert r.status_code == 201, r.text
    return r.json()


def gasto(client, auth, base, categoria, monto, fecha="2026-10-15", tipo="gasto"):
    r = client.post(
        "/api/v1/transactions",
        json={
            "account_id": base["cuenta"]["id"],
            "category_id": categoria["id"],
            "tipo": tipo,
            "monto": monto,
            "fecha": fecha,
        },
        headers=auth,
    )
    assert r.status_code == 201, r.text


def listar(client, auth, mes=10, anio=2026):
    r = client.get(URL, params={"mes": mes, "anio": anio}, headers=auth)
    assert r.status_code == 200, r.text
    return r.json()


# --------------------------------------------------- calculos puros


def test_las_alertas_saltan_justo_en_el_80_y_el_100():
    limite = Decimal("1000.00")
    assert alerta_para(Decimal("799.99"), limite) is None
    assert alerta_para(Decimal("800.00"), limite) == "atencion"
    assert alerta_para(Decimal("999.99"), limite) == "atencion"
    assert alerta_para(Decimal("1000.00"), limite) == "limite"
    assert alerta_para(Decimal("1500.00"), limite) == "limite"


def test_el_mes_anterior_de_enero_es_diciembre_del_ano_pasado():
    assert mes_anterior(1, 2027) == (12, 2026)
    assert mes_anterior(10, 2026) == (9, 2026)


# --------------------------------------------------- lo gastado


def test_un_presupuesto_nuevo_arranca_sin_gastos(client, auth, base):
    p = presupuesto(client, auth, base["comida"])
    assert Decimal(p["gastado"]) == 0
    assert Decimal(p["disponible"]) == Decimal("1000000.00")
    assert p["porcentaje"] == 0
    assert p["alerta"] is None
    assert p["categoria"]["nombre"] == "Alimentación"


def test_solo_cuentan_los_gastos_de_esa_categoria_y_ese_mes(client, auth, base):
    presupuesto(client, auth, base["comida"])
    gasto(client, auth, base, base["comida"], "300000.00")
    gasto(client, auth, base, base["comida"], "200000.00", fecha="2026-10-31")
    # Nada de esto tiene que sumar:
    gasto(client, auth, base, base["comida"], "999.00", fecha="2026-09-30")  # otro mes
    gasto(client, auth, base, base["comida"], "999.00", fecha="2026-11-01")  # otro mes
    gasto(client, auth, base, base["transporte"], "999.00")  # otra categoría
    gasto(client, auth, base, base["salario"], "999.00", tipo="ingreso")  # un ingreso

    [p] = listar(client, auth)
    assert Decimal(p["gastado"]) == Decimal("500000.00")
    assert Decimal(p["disponible"]) == Decimal("500000.00")
    assert p["porcentaje"] == 50


def test_alerta_de_atencion_al_llegar_al_80(client, auth, base):
    presupuesto(client, auth, base["comida"])
    gasto(client, auth, base, base["comida"], "800000.00")

    [p] = listar(client, auth)
    assert p["alerta"] == "atencion"
    assert p["porcentaje"] == 80


def test_alerta_de_limite_y_disponible_negativo_al_pasarse(client, auth, base):
    presupuesto(client, auth, base["comida"])
    gasto(client, auth, base, base["comida"], "1250000.00")

    [p] = listar(client, auth)
    assert p["alerta"] == "limite"
    assert p["porcentaje"] == 125
    assert Decimal(p["disponible"]) == Decimal("-250000.00")


def test_el_listado_es_solo_del_mes_pedido(client, auth, base):
    presupuesto(client, auth, base["comida"], mes=9)
    presupuesto(client, auth, base["comida"], mes=10)
    presupuesto(client, auth, base["transporte"], mes=10)

    assert len(listar(client, auth, mes=9)) == 1
    assert [p["categoria"]["nombre"] for p in listar(client, auth, mes=10)] == [
        "Alimentación",
        "Transporte",
    ]


# --------------------------------------------------- validaciones


def test_no_se_repite_la_categoria_en_el_mismo_mes(client, auth, base):
    presupuesto(client, auth, base["comida"])
    r = client.post(
        URL,
        json={"category_id": base["comida"]["id"], "mes": 10, "anio": 2026, "limite": "5.00"},
        headers=auth,
    )
    assert r.status_code == 409
    # En otro mes sí se puede.
    presupuesto(client, auth, base["comida"], mes=11)


def test_no_se_presupuesta_una_categoria_de_ingreso(client, auth, base):
    r = client.post(
        URL,
        json={"category_id": base["salario"]["id"], "mes": 10, "anio": 2026, "limite": "5.00"},
        headers=auth,
    )
    assert r.status_code == 422
    assert "gasto" in r.json()["detail"]


@pytest.mark.parametrize(
    ("campo", "valor"),
    [("limite", "0"), ("limite", "-10.00"), ("mes", 13), ("mes", 0), ("anio", 1999)],
)
def test_datos_invalidos_son_rechazados(client, auth, base, campo, valor):
    cuerpo = {"category_id": base["comida"]["id"], "mes": 10, "anio": 2026, "limite": "5.00"}
    cuerpo[campo] = valor
    assert client.post(URL, json=cuerpo, headers=auth).status_code == 422


# --------------------------------------------------- editar y borrar


def test_editar_el_limite_recalcula_la_alerta(client, auth, base):
    p = presupuesto(client, auth, base["comida"])
    gasto(client, auth, base, base["comida"], "900000.00")

    r = client.patch(f"{URL}/{p['id']}", json={"limite": "2000000.00"}, headers=auth)
    assert r.status_code == 200
    assert r.json()["alerta"] is None
    assert r.json()["porcentaje"] == 45


def test_eliminar_un_presupuesto(client, auth, base):
    p = presupuesto(client, auth, base["comida"])
    assert client.delete(f"{URL}/{p['id']}", headers=auth).status_code == 204
    assert listar(client, auth) == []
    assert client.delete(f"{URL}/{p['id']}", headers=auth).status_code == 404


def test_borrar_la_categoria_borra_sus_presupuestos(client, auth, base):
    r = client.post(
        "/api/v1/categories",
        json={"nombre": "Mascotas", "tipo": "gasto", "icono": "pets", "color": "#FF9800"},
        headers=auth,
    )
    mascotas = r.json()
    presupuesto(client, auth, mascotas)

    assert client.delete(f"/api/v1/categories/{mascotas['id']}", headers=auth).status_code == 204
    assert listar(client, auth) == []


# --------------------------------------------------- copiar del mes anterior


def test_copiar_repite_los_limites_del_mes_anterior(client, auth, base):
    presupuesto(client, auth, base["comida"], limite="1000.00", mes=9)
    presupuesto(client, auth, base["transporte"], limite="500.00", mes=9)
    # Comida ya tiene presupuesto en octubre: no se pisa.
    presupuesto(client, auth, base["comida"], limite="1200.00", mes=10)

    r = client.post(f"{URL}/copiar", json={"mes": 10, "anio": 2026}, headers=auth)
    assert r.status_code == 200
    assert r.json() == {"copiados": 1}

    limites = {p["categoria"]["nombre"]: Decimal(p["limite"]) for p in listar(client, auth)}
    assert limites == {"Alimentación": Decimal("1200.00"), "Transporte": Decimal("500.00")}

    # Copiar de nuevo no duplica nada.
    r = client.post(f"{URL}/copiar", json={"mes": 10, "anio": 2026}, headers=auth)
    assert r.json() == {"copiados": 0}


def test_copiar_en_enero_toma_diciembre_del_ano_anterior(client, auth, base):
    presupuesto(client, auth, base["comida"], mes=12, anio=2026)
    r = client.post(f"{URL}/copiar", json={"mes": 1, "anio": 2027}, headers=auth)
    assert r.json() == {"copiados": 1}
    assert len(listar(client, auth, mes=1, anio=2027)) == 1


# --------------------------------------------------- aislamiento entre usuarios


def test_nadie_ve_ni_toca_presupuestos_ajenos(client, auth, base):
    p = presupuesto(client, auth, base["comida"])
    gasto(client, auth, base, base["comida"], "500000.00")
    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")

    assert listar(client, otro) == []
    assert client.patch(f"{URL}/{p['id']}", json={"limite": "1.00"}, headers=otro).status_code == 404
    assert client.delete(f"{URL}/{p['id']}", headers=otro).status_code == 404
    # Copiar tampoco le trae los presupuestos de Ana.
    client.post(f"{URL}/copiar", json={"mes": 11, "anio": 2026}, headers=otro)
    assert listar(client, otro, mes=11) == []


def test_los_gastos_de_otro_usuario_no_cuentan(client, auth, base):
    presupuesto(client, auth, base["comida"])
    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")
    cuenta_otro = crear_cuenta(client, otro)
    gasto(client, otro, {"cuenta": cuenta_otro}, base["comida"], "999999.00")

    [p] = listar(client, auth)
    assert Decimal(p["gastado"]) == 0


def test_no_se_presupuesta_una_categoria_ajena(client, auth, base):
    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")
    r = client.post(
        "/api/v1/categories",
        json={"nombre": "Privada", "tipo": "gasto", "icono": "lock", "color": "#000000"},
        headers=otro,
    )
    r = client.post(
        URL,
        json={"category_id": r.json()["id"], "mes": 10, "anio": 2026, "limite": "5.00"},
        headers=auth,
    )
    assert r.status_code == 404


def test_sin_sesion_no_hay_presupuestos(client):
    assert client.get(URL).status_code == 401
