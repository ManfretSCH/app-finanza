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

