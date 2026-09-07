"""Pruebas de los informes (RF-006).

Se arma un mes con movimientos conocidos y se verifica que los numeros que
devuelve la API sean exactamente los que uno calcularia a mano.
"""

from datetime import date

import pytest

from app.services.reports import dias_a_promediar
from tests.conftest import crear_cuenta


@pytest.fixture
def mes_cargado(client, auth):
    """Septiembre de 2026: 3.000.000 de ingreso y 300.000 de gastos en 3 dias."""
    cuenta = crear_cuenta(client, auth, saldo="0.00")
    categorias = client.get("/api/v1/categories", headers=auth).json()
    alimentacion = next(c for c in categorias if c["nombre"] == "Alimentacion")
    transporte = next(c for c in categorias if c["nombre"] == "Transporte")
    salario = next(c for c in categorias if c["nombre"] == "Salario")

    movimientos = [
        (salario, "ingreso", "3000000.00", "2026-09-01"),
        (alimentacion, "gasto", "200000.00", "2026-09-05"),
        (transporte, "gasto", "50000.00", "2026-09-05"),
        (transporte, "gasto", "50000.00", "2026-09-10"),
        # Un mes distinto, para comprobar que no se cuela en el informe de septiembre.
        (alimentacion, "gasto", "999999.00", "2026-08-15"),
    ]
    for categoria, tipo, monto, fecha in movimientos:
        r = client.post(
            "/api/v1/transactions",
            json={
                "account_id": cuenta["id"],
                "category_id": categoria["id"],
                "tipo": tipo,
                "monto": monto,
                "fecha": fecha,
            },
            headers=auth,
        )
        assert r.status_code == 201, r.text
    return cuenta


def test_resumen_del_mes(client, auth, mes_cargado):
    r = client.get("/api/v1/reports/resumen?mes=9&anio=2026", headers=auth)
    assert r.status_code == 200
    d = r.json()

    assert float(d["ingresos"]) == 3000000.0
    assert float(d["gastos"]) == 300000.0
    assert float(d["balance"]) == 2700000.0
    # El gasto de agosto no debe aparecer en el resumen de septiembre.
    assert d["cantidad_movimientos"] == 4


def test_promedio_diario_de_gasto(client, auth, mes_cargado):
    d = client.get("/api/v1/reports/resumen?mes=9&anio=2026", headers=auth).json()
    esperado = 300000.0 / d["dias_considerados"]
    assert float(d["promedio_diario_gasto"]) == pytest.approx(esperado, abs=0.01)


def test_los_dias_se_cuentan_hasta_hoy_si_el_mes_esta_en_curso():
    hoy = date(2026, 9, 7)
    # Mes en curso: solo los dias transcurridos, si no el promedio saldria muy bajo.
    assert dias_a_promediar(9, 2026, hoy) == 7
    # Mes ya terminado: el mes completo.
    assert dias_a_promediar(8, 2026, hoy) == 31


def test_en_que_se_va_la_plata(client, auth, mes_cargado):
    r = client.get("/api/v1/reports/por-categoria?tipo=gasto&mes=9&anio=2026", headers=auth)
    filas = r.json()

    assert len(filas) == 2
    # Ordenado de mayor a menor.
    assert filas[0]["categoria"]["nombre"] == "Alimentacion"
    assert float(filas[0]["total"]) == 200000.0
    assert filas[0]["porcentaje"] == pytest.approx(66.7, abs=0.1)

    assert filas[1]["categoria"]["nombre"] == "Transporte"
    assert float(filas[1]["total"]) == 100000.0
    assert filas[1]["cantidad"] == 2  # dos movimientos sumados
    assert filas[1]["porcentaje"] == pytest.approx(33.3, abs=0.1)

    assert sum(f["porcentaje"] for f in filas) == pytest.approx(100.0, abs=0.1)


def test_de_donde_vienen_los_ingresos(client, auth, mes_cargado):
    filas = client.get(
        "/api/v1/reports/por-categoria?tipo=ingreso&mes=9&anio=2026", headers=auth
    ).json()

    assert len(filas) == 1
    assert filas[0]["categoria"]["nombre"] == "Salario"
    assert filas[0]["porcentaje"] == pytest.approx(100.0, abs=0.1)


def test_gasto_por_dia(client, auth, mes_cargado):
    dias = client.get("/api/v1/reports/por-dia?mes=9&anio=2026", headers=auth).json()

    # Todos los dias del mes, incluidos los que no tuvieron movimientos,
    # para que el grafico quede continuo.
    assert len(dias) == 30

    por_fecha = {d["fecha"]: d for d in dias}
    assert float(por_fecha["2026-09-05"]["gastos"]) == 250000.0  # 200.000 + 50.000
    assert float(por_fecha["2026-09-01"]["ingresos"]) == 3000000.0
    assert float(por_fecha["2026-09-02"]["gastos"]) == 0.0


def test_tendencia_del_ano(client, auth, mes_cargado):
    meses = client.get("/api/v1/reports/por-mes?anio=2026", headers=auth).json()

    assert len(meses) == 12
    agosto, septiembre = meses[7], meses[8]

    assert float(agosto["gastos"]) == 999999.0
    assert float(septiembre["gastos"]) == 300000.0
    assert float(septiembre["balance"]) == 2700000.0
    assert float(meses[0]["gastos"]) == 0.0  # enero sin movimientos


def test_los_informes_no_mezclan_usuarios(client, auth, mes_cargado):
    """Aislamiento: el informe de otro usuario tiene que estar en cero (RNF-002)."""
    from tests.conftest import registrar_usuario

    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")
    d = client.get("/api/v1/reports/resumen?mes=9&anio=2026", headers=otro).json()

    assert float(d["ingresos"]) == 0.0
    assert float(d["gastos"]) == 0.0
    assert d["cantidad_movimientos"] == 0
    assert client.get("/api/v1/reports/por-categoria?mes=9&anio=2026", headers=otro).json() == []
