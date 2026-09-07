"""Pruebas de cuentas y del calculo de saldos (RF-001)."""

from tests.conftest import registrar_usuario


def crear_cuenta(client, auth, nombre="Caja de ahorro", saldo="1000.00"):
    r = client.post(
        "/api/v1/accounts",
        json={"nombre": nombre, "tipo": "ahorro", "saldo_inicial": saldo, "moneda": "PYG"},
        headers=auth,
    )
    assert r.status_code == 201, r.text
    return r.json()


def test_crear_y_listar_cuenta(client, auth):
    crear_cuenta(client, auth)
    r = client.get("/api/v1/accounts", headers=auth)
    assert r.status_code == 200
    cuentas = r.json()
    assert len(cuentas) == 1
    assert cuentas[0]["nombre"] == "Caja de ahorro"
    assert float(cuentas[0]["saldo_actual"]) == 1000.0


def test_el_saldo_refleja_ingresos_y_gastos(client, auth):
    """El saldo se calcula, no se guarda: debe seguir a los movimientos."""
    cuenta = crear_cuenta(client, auth, saldo="1000.00")
    categorias = client.get("/api/v1/categories", headers=auth).json()
    gasto = next(c for c in categorias if c["tipo"] == "gasto")
    ingreso = next(c for c in categorias if c["tipo"] == "ingreso")

    client.post(
        "/api/v1/transactions",
        json={
            "account_id": cuenta["id"], "category_id": gasto["id"], "tipo": "gasto",
            "monto": "250.50", "fecha": "2026-09-01",
        },
        headers=auth,
    )
    client.post(
        "/api/v1/transactions",
        json={
            "account_id": cuenta["id"], "category_id": ingreso["id"], "tipo": "ingreso",
            "monto": "500.00", "fecha": "2026-09-02",
        },
        headers=auth,
    )

    saldo = client.get(f"/api/v1/accounts/{cuenta['id']}", headers=auth).json()["saldo_actual"]
    assert float(saldo) == 1000.00 - 250.50 + 500.00


def test_no_se_borra_una_cuenta_con_movimientos(client, auth):
    cuenta = crear_cuenta(client, auth)
    categoria = client.get("/api/v1/categories", headers=auth).json()[0]
    client.post(
        "/api/v1/transactions",
        json={
            "account_id": cuenta["id"], "category_id": categoria["id"], "tipo": "gasto",
            "monto": "10.00", "fecha": "2026-09-01",
        },
        headers=auth,
    )
    r = client.delete(f"/api/v1/accounts/{cuenta['id']}", headers=auth)
    assert r.status_code == 409


def test_un_usuario_no_ve_las_cuentas_de_otro(client, auth):
    """Prueba de aislamiento entre usuarios (RNF-002)."""
    cuenta_de_ana = crear_cuenta(client, auth)

    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")
    assert client.get("/api/v1/accounts", headers=otro).json() == []
    assert client.get(f"/api/v1/accounts/{cuenta_de_ana['id']}", headers=otro).status_code == 404
    assert client.delete(f"/api/v1/accounts/{cuenta_de_ana['id']}", headers=otro).status_code == 404
