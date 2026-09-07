"""Configuracion de las pruebas.

Se usa una base de datos aparte (finanzas_test) que se recrea en cada corrida,
para no tocar nunca los datos de desarrollo.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.db.seed import CATEGORIAS_PREDEFINIDAS
from app.db.session import Base, get_db
from app.main import app
from app.models import Category

TEST_DB_URL = settings.DATABASE_URL.rsplit("/", 1)[0] + "/finanzas_test"


@pytest.fixture(scope="session", autouse=True)
def crear_base_de_pruebas():
    """Crea la base finanzas_test si no existe."""
    admin = create_engine(settings.DATABASE_URL, isolation_level="AUTOCOMMIT")
    with admin.connect() as conn:
        existe = conn.execute(
            text("select 1 from pg_database where datname = 'finanzas_test'")
        ).scalar()
        if not existe:
            conn.execute(text("create database finanzas_test"))
    admin.dispose()


@pytest.fixture
def db_session(crear_base_de_pruebas):
    """Tablas limpias para cada prueba: ninguna prueba depende de otra."""
    engine = create_engine(TEST_DB_URL)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    Session = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    session = Session()

    # Las categorias predefinidas son parte del estado base del sistema.
    for nombre, tipo, icono, color in CATEGORIAS_PREDEFINIDAS:
        session.add(Category(user_id=None, nombre=nombre, tipo=tipo, icono=icono, color=color))
    session.commit()

    yield session

    session.close()
    engine.dispose()


@pytest.fixture
def client(db_session):
    """Cliente HTTP que usa la sesion de pruebas en lugar de la base real."""
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def registrar_usuario(client, email="ana@example.com", password="secreta123", nombre="Ana"):
    """Atajo: crea un usuario y devuelve las cabeceras con su token."""
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "nombre": nombre, "password": password},
    )
    assert r.status_code == 201, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def auth(client):
    return registrar_usuario(client)
