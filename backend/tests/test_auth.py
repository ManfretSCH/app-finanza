"""Pruebas de registro, login y perfil (RF-007)."""

from tests.conftest import registrar_usuario


def test_registro_devuelve_token_y_no_expone_la_password(client):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": "ana@example.com", "nombre": "Ana", "password": "secreta123"},
    )
    assert r.status_code == 201
    cuerpo = r.json()
    assert cuerpo["access_token"]
    assert cuerpo["usuario"]["email"] == "ana@example.com"
    # La respuesta nunca debe incluir el hash ni la contrasena.
    assert "password" not in str(cuerpo["usuario"])
    assert "password_hash" not in cuerpo["usuario"]


def test_no_se_puede_repetir_el_correo(client):
    registrar_usuario(client)
    r = client.post(
        "/api/v1/auth/register",
        json={"email": "ana@example.com", "nombre": "Otra", "password": "secreta123"},
    )
    assert r.status_code == 409


def test_password_corta_es_rechazada(client):
    r = client.post(
        "/api/v1/auth/register",
        json={"email": "b@example.com", "nombre": "Bob", "password": "corta"},
    )
    assert r.status_code == 422


def test_login_correcto_e_incorrecto(client):
    registrar_usuario(client)

    ok = client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "secreta123"}
    )
    assert ok.status_code == 200
    assert ok.json()["access_token"]

    mal = client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "equivocada"}
    )
    assert mal.status_code == 401


def test_endpoint_protegido_exige_token(client, auth):
    assert client.get("/api/v1/auth/me").status_code == 401
    assert client.get("/api/v1/auth/me", headers={"Authorization": "Bearer basura"}).status_code == 401
    assert client.get("/api/v1/auth/me", headers=auth).status_code == 200


def test_cambio_de_password(client, auth):
    fallido = client.post(
        "/api/v1/auth/change-password",
        json={"password_actual": "equivocada", "password_nueva": "nuevaclave1"},
        headers=auth,
    )
    assert fallido.status_code == 400

    ok = client.post(
        "/api/v1/auth/change-password",
        json={"password_actual": "secreta123", "password_nueva": "nuevaclave1"},
        headers=auth,
    )
    assert ok.status_code == 204

    # La vieja ya no sirve y la nueva si.
    assert client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "secreta123"}
    ).status_code == 401
    assert client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "nuevaclave1"}
    ).status_code == 200
