"""Pruebas de la carga de datos predefinidos.

Nace de un error real: al corregirle el acento a "Alimentacion", el seed dejo
de reconocerla y la creo de nuevo, quedando duplicada con "Alimentación".
"""

from sqlalchemy import select

from app.db.seed import CATEGORIAS_PREDEFINIDAS, _sin_acentos
from app.models import Category


def test_comparacion_sin_acentos():
    assert _sin_acentos("Alimentación") == _sin_acentos("Alimentacion")
    assert _sin_acentos("Tarjeta de crédito") == _sin_acentos("TARJETA DE CREDITO")
    assert _sin_acentos("Salud") != _sin_acentos("Salario")


def test_no_hay_dos_predefinidas_que_se_confundan():
    """Dos nombres que solo se diferencian en un acento serian indistinguibles."""
    claves = [_sin_acentos(nombre) for nombre, *_ in CATEGORIAS_PREDEFINIDAS]
    assert len(claves) == len(set(claves))


def test_una_predefinida_sin_acento_se_corrige_en_vez_de_duplicarse(db_session, monkeypatch):
    """El caso exacto que fallo: la base tiene la version vieja del nombre."""
    from app.db import seed

    vieja = db_session.scalar(
        select(Category).where(Category.user_id.is_(None), Category.nombre == "Alimentación")
    )
    assert vieja is not None
    vieja.nombre = "Alimentacion"  # como estaba antes de corregir los acentos
    db_session.commit()

    # El seed usa su propia sesion; se la apunta a la de la prueba.
    monkeypatch.setattr(seed, "SessionLocal", lambda: db_session)
    # La sesion de la prueba no debe cerrarse al salir del with del seed.
    monkeypatch.setattr(type(db_session), "__enter__", lambda s: s, raising=False)
    monkeypatch.setattr(type(db_session), "__exit__", lambda s, *a: None, raising=False)

    creadas = seed.cargar_categorias_predefinidas()

    assert creadas == 0, "no deberia crear ninguna: ya estaba, solo mal escrita"
    nombres = db_session.scalars(
        select(Category.nombre).where(Category.user_id.is_(None))
    ).all()
    assert "Alimentación" in nombres
    assert "Alimentacion" not in nombres
    assert len(nombres) == len(set(nombres))
