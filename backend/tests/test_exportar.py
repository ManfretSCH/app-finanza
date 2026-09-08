"""Pruebas de la exportacion a CSV y PDF (RF-006, RF-007)."""

import csv
import io
from decimal import Decimal

import pytest

from app.services.exportar import _monto_es
from tests.conftest import crear_cuenta, registrar_usuario


@pytest.fixture
def mes_cargado(client, auth):
    """Septiembre de 2026 con un ingreso y dos gastos."""
    cuenta = crear_cuenta(client, auth, nombre="Caja", saldo="0.00")
    categorias = client.get("/api/v1/categories", headers=auth).json()
    alimentacion = next(c for c in categorias if c["nombre"] == "Alimentación")
    salario = next(c for c in categorias if c["nombre"] == "Salario")

    for categoria, tipo, monto, fecha, desc in [
        (salario, "ingreso", "4500000.00", "2026-09-01", "Sueldo"),
        (alimentacion, "gasto", "185000.00", "2026-09-02", "Supermercado"),
        (alimentacion, "gasto", "48000.00", "2026-09-04", "Almuerzo"),
        # Otro mes, para comprobar que no se cuela en la exportacion.
        (alimentacion, "gasto", "999999.00", "2026-08-10", "Compra de agosto"),
    ]:
        r = client.post(
            "/api/v1/transactions",
            json={
                "account_id": cuenta["id"], "category_id": categoria["id"], "tipo": tipo,
                "monto": monto, "fecha": fecha, "descripcion": desc,
            },
            headers=auth,
        )
        assert r.status_code == 201, r.text
    return cuenta


def leer_csv(contenido: bytes) -> list[list[str]]:
    texto = contenido.decode("utf-8-sig")  # descarta el BOM
    return list(csv.reader(io.StringIO(texto), delimiter=";"))


def test_el_csv_trae_los_movimientos_del_mes(client, auth, mes_cargado):
    r = client.get("/api/v1/reports/export?formato=csv&mes=9&anio=2026", headers=auth)
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/csv")
    assert 'filename="finanzas-2026-09.csv"' in r.headers["content-disposition"]

    filas = leer_csv(r.content)
    assert filas[0] == ["Fecha", "Tipo", "Categoría", "Cuenta", "Monto", "Descripción"]

    movimientos = [f for f in filas[1:] if f and f[0] and "/" in f[0]]
    assert len(movimientos) == 3  # el de agosto no aparece

    primero = movimientos[0]
    assert primero[0] == "01/09/2026"
    assert primero[1] == "Ingreso"
    assert primero[2] == "Salario"
    assert primero[4] == "4.500.000,00"
    assert primero[5] == "Sueldo"


def test_el_csv_cierra_con_los_totales(client, auth, mes_cargado):
    filas = leer_csv(
        client.get("/api/v1/reports/export?formato=csv&mes=9&anio=2026", headers=auth).content
    )
    totales = {f[0]: f[4] for f in filas if f and f[0].startswith(("Total", "Balance"))}

    assert totales["Total ingresos"] == "4.500.000,00"
    assert totales["Total gastos"] == "233.000,00"
    assert totales["Balance"] == "4.267.000,00"


def test_el_csv_empieza_con_el_bom_para_que_excel_lea_utf8(client, auth, mes_cargado):
    contenido = client.get(
        "/api/v1/reports/export?formato=csv&mes=9&anio=2026", headers=auth
    ).content
    assert contenido.startswith(b"\xef\xbb\xbf")


def test_el_pdf_es_un_pdf_valido(client, auth, mes_cargado):
    r = client.get("/api/v1/reports/export?formato=pdf&mes=9&anio=2026", headers=auth)
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/pdf"
    assert 'filename="finanzas-2026-09.pdf"' in r.headers["content-disposition"]

    assert r.content.startswith(b"%PDF-")
    assert r.content.rstrip().endswith(b"%%EOF")
    # Un informe con tablas pesa bastante mas que un PDF vacio.
    assert len(r.content) > 2000


def test_se_puede_exportar_un_mes_sin_movimientos(client, auth):
    """No debe romperse: es lo que pasa al abrir un mes nuevo."""
    for formato in ["csv", "pdf"]:
        r = client.get(
            f"/api/v1/reports/export?formato={formato}&mes=1&anio=2026", headers=auth
        )
        assert r.status_code == 200, formato
        assert len(r.content) > 0


def test_la_exportacion_no_mezcla_usuarios(client, auth, mes_cargado):
    """Aislamiento: otro usuario exporta lo suyo, que esta vacio (RNF-002)."""
    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")
    filas = leer_csv(
        client.get("/api/v1/reports/export?formato=csv&mes=9&anio=2026", headers=otro).content
    )
    movimientos = [f for f in filas[1:] if f and f[0] and "/" in f[0]]
    assert movimientos == []


def test_exportar_exige_sesion(client):
    assert client.get("/api/v1/reports/export?formato=csv").status_code == 401


@pytest.mark.parametrize(
    ("valor", "esperado"),
    [
        ("0", "0,00"),
        ("1234567.89", "1.234.567,89"),
        ("-85000", "-85.000,00"),
        ("999", "999,00"),
        ("1000", "1.000,00"),
    ],
)
def test_formato_de_montos(valor, esperado):
    assert _monto_es(Decimal(valor)) == esperado
