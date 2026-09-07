"""Pruebas de los tipos de cuenta editables."""

from tests.conftest import crear_cuenta, registrar_usuario


def test_los_predefinidos_estan_disponibles(client, auth):
    tipos = client.get("/api/v1/account-types", headers=auth).json()
    assert len(tipos) == 4
    assert {t["nombre"] for t in tipos} == {
        "Caja de ahorro",
        "Cuenta corriente",
        "Tarjeta de credito",
        "Efectivo",
    }
    assert all(t["es_predefinido"] for t in tipos)


def test_crear_un_tipo_propio(client, auth):
    r = client.post(
        "/api/v1/account-types",
        json={"nombre": "Billetera virtual", "icono": "smartphone"},
        headers=auth,
    )
    assert r.status_code == 201
    assert r.json()["es_predefinido"] is False
    assert len(client.get("/api/v1/account-types", headers=auth).json()) == 5


def test_no_se_puede_modificar_un_predefinido(client, auth):
    predefinido = client.get("/api/v1/account-types", headers=auth).json()[0]
    assert (
        client.patch(
            f"/api/v1/account-types/{predefinido['id']}", json={"nombre": "X"}, headers=auth
        ).status_code
        == 403
    )
    assert (
        client.delete(f"/api/v1/account-types/{predefinido['id']}", headers=auth).status_code == 403
    )


def test_no_se_borra_un_tipo_en_uso(client, auth):
    tipo = client.post(
        "/api/v1/account-types", json={"nombre": "Billetera virtual"}, headers=auth
    ).json()
    client.post(
        "/api/v1/accounts",
        json={"nombre": "Tigo Money", "account_type_id": tipo["id"], "saldo_inicial": "0.00"},
        headers=auth,
    )
    r = client.delete(f"/api/v1/account-types/{tipo['id']}", headers=auth)
    assert r.status_code == 409


def test_un_usuario_no_usa_el_tipo_de_otro(client, auth):
    """Aislamiento: no se puede crear una cuenta con un tipo ajeno (RNF-002)."""
    tipo_de_ana = client.post(
        "/api/v1/account-types", json={"nombre": "Billetera de Ana"}, headers=auth
    ).json()

    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")
    assert len(client.get("/api/v1/account-types", headers=otro).json()) == 4  # solo los del sistema

    r = client.post(
        "/api/v1/accounts",
        json={"nombre": "Intruso", "account_type_id": tipo_de_ana["id"], "saldo_inicial": "0.00"},
        headers=otro,
    )
    assert r.status_code == 404


def test_la_cuenta_devuelve_su_tipo_anidado(client, auth):
    crear_cuenta(client, auth)
    cuenta = client.get("/api/v1/accounts", headers=auth).json()[0]
    assert cuenta["tipo"]["nombre"] == "Caja de ahorro"
