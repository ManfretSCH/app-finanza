"""Pruebas del limite de intentos de inicio de sesion.

Importa sobre todo ahora que el backend queda publicado en internet: sin esto
cualquiera podria probar contrasenas indefinidamente.
"""

import pytest

from app.core import limites
from app.core.config import settings

CREDENCIALES_MALAS = {"email": "ana@example.com", "password": "equivocada"}


@pytest.fixture(autouse=True)
def contador_limpio():
    """El contador vive en memoria del proceso: cada prueba arranca de cero."""
    limites.reiniciar()
    yield
    limites.reiniciar()


def test_se_bloquea_tras_demasiados_intentos(client, auth):
    for _ in range(settings.INTENTOS_LOGIN_MAXIMOS):
        r = client.post("/api/v1/auth/login", json=CREDENCIALES_MALAS)
        assert r.status_code == 401

    bloqueado = client.post("/api/v1/auth/login", json=CREDENCIALES_MALAS)
    assert bloqueado.status_code == 429
    assert "intentos" in bloqueado.json()["detail"].lower()


def test_el_bloqueo_alcanza_tambien_a_la_contrasena_correcta(client, auth):
    """Si no, bastaria con acertar en el intento numero once."""
    for _ in range(settings.INTENTOS_LOGIN_MAXIMOS):
        client.post("/api/v1/auth/login", json=CREDENCIALES_MALAS)

    r = client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "secreta123"}
    )
    assert r.status_code == 429


def test_un_acierto_borra_los_fallos_previos(client, auth):
    for _ in range(settings.INTENTOS_LOGIN_MAXIMOS - 1):
        client.post("/api/v1/auth/login", json=CREDENCIALES_MALAS)

    ok = client.post(
        "/api/v1/auth/login", json={"email": "ana@example.com", "password": "secreta123"}
    )
    assert ok.status_code == 200

    # Tras el acierto vuelve a tener todos los intentos disponibles.
    for _ in range(settings.INTENTOS_LOGIN_MAXIMOS):
        assert client.post("/api/v1/auth/login", json=CREDENCIALES_MALAS).status_code == 401


def test_el_registro_no_esta_limitado(client, auth):
    """Solo se limita el login: bloquear el registro dejaria fuera a usuarios nuevos."""
    for _ in range(settings.INTENTOS_LOGIN_MAXIMOS + 2):
        client.post("/api/v1/auth/login", json=CREDENCIALES_MALAS)

    r = client.post(
        "/api/v1/auth/register",
        json={"email": "nuevo@example.com", "nombre": "Nuevo", "password": "secreta123"},
    )
    assert r.status_code == 201
