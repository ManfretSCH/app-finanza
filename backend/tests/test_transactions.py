"""Pruebas de transacciones y categorias (RF-002, RF-003)."""

from tests.conftest import crear_cuenta, registrar_usuario


def preparar(client, auth):
    cuenta = crear_cuenta(client, auth, nombre="Efectivo", saldo="0.00")
    categorias = client.get("/api/v1/categories", headers=auth).json()
    return cuenta, categorias


def test_categorias_predefinidas_disponibles_para_todos(client, auth):
    categorias = client.get("/api/v1/categories", headers=auth).json()
    assert len(categorias) == 13
    assert all(c["es_predefinida"] for c in categorias)


def test_no_se_puede_editar_una_categoria_predefinida(client, auth):
    predefinida = client.get("/api/v1/categories", headers=auth).json()[0]
    r = client.patch(
        f"/api/v1/categories/{predefinida['id']}", json={"nombre": "Hackeada"}, headers=auth
    )
    assert r.status_code == 403


def test_categoria_personalizada(client, auth):
    r = client.post(
        "/api/v1/categories",
        json={"nombre": "Mascotas", "tipo": "gasto", "icono": "pets", "color": "#FF9800"},
        headers=auth,
    )
    assert r.status_code == 201
    assert r.json()["es_predefinida"] is False
    assert len(client.get("/api/v1/categories", headers=auth).json()) == 14


def test_monto_negativo_o_cero_es_rechazado(client, auth):
    cuenta, categorias = preparar(client, auth)
    for monto in ["-100.00", "0.00"]:
        r = client.post(
            "/api/v1/transactions",
            json={
                "account_id": cuenta["id"], "category_id": categorias[0]["id"], "tipo": "gasto",
                "monto": monto, "fecha": "2026-09-01",
            },
            headers=auth,
        )
        assert r.status_code == 422, f"monto {monto} deberia rechazarse"


def test_filtros_del_listado(client, auth):
    cuenta, categorias = preparar(client, auth)
    gasto = next(c for c in categorias if c["tipo"] == "gasto")
    ingreso = next(c for c in categorias if c["tipo"] == "ingreso")

    for cat, tipo, fecha in [
        (gasto, "gasto", "2026-09-01"),
        (gasto, "gasto", "2026-09-15"),
        (ingreso, "ingreso", "2026-10-01"),
    ]:
        client.post(
            "/api/v1/transactions",
            json={
                "account_id": cuenta["id"], "category_id": cat["id"], "tipo": tipo,
                "monto": "100.00", "fecha": fecha,
            },
            headers=auth,
        )

    assert client.get("/api/v1/transactions", headers=auth).json()["total"] == 3
    assert client.get("/api/v1/transactions?tipo=gasto", headers=auth).json()["total"] == 2
    assert (
        client.get(f"/api/v1/transactions?category_id={ingreso['id']}", headers=auth).json()["total"]
        == 1
    )
    assert (
        client.get("/api/v1/transactions?desde=2026-09-10&hasta=2026-09-30", headers=auth)
        .json()["total"]
        == 1
    )


def test_no_se_puede_registrar_en_la_cuenta_de_otro(client, auth):
    """Aislamiento: mandar el id de una cuenta ajena debe fallar (RNF-002)."""
    cuenta_de_ana, categorias = preparar(client, auth)
    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")

    r = client.post(
        "/api/v1/transactions",
        json={
            "account_id": cuenta_de_ana["id"], "category_id": categorias[0]["id"],
            "tipo": "gasto", "monto": "100.00", "fecha": "2026-09-01",
        },
        headers=otro,
    )
    assert r.status_code == 404


def test_un_usuario_no_ve_las_categorias_de_otro(client, auth):
    """Aislamiento de categorias (RNF-002).

    Las predefinidas son de todos, pero una categoria que crea alguien es suya:
    no aparece en la lista de los demas, no la pueden editar ni borrar, y no
    pueden clasificar sus movimientos con ella.
    """
    propia = client.post(
        "/api/v1/categories",
        json={"nombre": "Mascotas", "tipo": "gasto", "icono": "pets", "color": "#FF9800"},
        headers=auth,
    ).json()

    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")

    # No la ve: solo las 13 del sistema.
    categorias_del_otro = client.get("/api/v1/categories", headers=otro).json()
    assert len(categorias_del_otro) == 13
    assert "Mascotas" not in [c["nombre"] for c in categorias_del_otro]

    # No la puede modificar ni borrar. Se responde 404 y no 403 a proposito:
    # un usuario no deberia poder deducir que categorias existen de otros.
    assert client.patch(
        f"/api/v1/categories/{propia['id']}", json={"nombre": "Robada"}, headers=otro
    ).status_code == 404
    assert client.delete(f"/api/v1/categories/{propia['id']}", headers=otro).status_code == 404

    # Tampoco puede usarla al registrar un movimiento.
    cuenta_del_otro = crear_cuenta(client, otro, nombre="Efectivo", saldo="0.00")
    r = client.post(
        "/api/v1/transactions",
        json={
            "account_id": cuenta_del_otro["id"], "category_id": propia["id"],
            "tipo": "gasto", "monto": "1000.00", "fecha": "2026-09-01",
        },
        headers=otro,
    )
    assert r.status_code == 404

    # Y el dueño la sigue viendo con normalidad.
    assert "Mascotas" in [c["nombre"] for c in client.get("/api/v1/categories", headers=auth).json()]


def test_editar_cambia_el_tipo_y_la_cuenta(client, auth):
    """Editar es lo que permite corregir un movimiento cargado mal.

    Es el caso de haber registrado un ingreso como gasto, o en la cuenta
    equivocada: se corrige sin borrar y volver a cargar.
    """
    origen = crear_cuenta(client, auth, nombre="Caja", saldo="0.00")
    destino = crear_cuenta(client, auth, nombre="Efectivo", saldo="0.00")
    categorias = client.get("/api/v1/categories", headers=auth).json()
    gasto = next(c for c in categorias if c["tipo"] == "gasto")
    ingreso = next(c for c in categorias if c["tipo"] == "ingreso")

    movimiento = client.post(
        "/api/v1/transactions",
        json={
            "account_id": origen["id"], "category_id": gasto["id"], "tipo": "gasto",
            "monto": "100000.00", "fecha": "2026-09-01", "descripcion": "Mal cargado",
        },
        headers=auth,
    ).json()

    assert float(
        client.get(f"/api/v1/accounts/{origen['id']}", headers=auth).json()["saldo_actual"]
    ) == -100000.0

    r = client.patch(
        f"/api/v1/transactions/{movimiento['id']}",
        json={
            "account_id": destino["id"], "category_id": ingreso["id"], "tipo": "ingreso",
            "monto": "250000.00", "fecha": "2026-09-05", "descripcion": "Corregido",
        },
        headers=auth,
    )
    assert r.status_code == 200
    editado = r.json()
    assert editado["tipo"] == "ingreso"
    assert editado["account_id"] == destino["id"]
    assert float(editado["monto"]) == 250000.0
    assert editado["descripcion"] == "Corregido"

    # Los dos saldos tienen que reflejar el cambio: el movimiento se fue de una
    # cuenta y aparecio en la otra, ya como ingreso.
    saldos = {
        c["nombre"]: float(c["saldo_actual"])
        for c in client.get("/api/v1/accounts", headers=auth).json()
    }
    assert saldos["Caja"] == 0.0
    assert saldos["Efectivo"] == 250000.0


def test_no_se_puede_editar_el_movimiento_de_otro(client, auth):
    """Aislamiento al editar (RNF-002)."""
    cuenta, categorias = preparar(client, auth)
    movimiento = client.post(
        "/api/v1/transactions",
        json={
            "account_id": cuenta["id"], "category_id": categorias[0]["id"],
            "tipo": "gasto", "monto": "1000.00", "fecha": "2026-09-01",
        },
        headers=auth,
    ).json()

    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")
    r = client.patch(
        f"/api/v1/transactions/{movimiento['id']}", json={"monto": "999999.00"}, headers=otro
    )
    assert r.status_code == 404

