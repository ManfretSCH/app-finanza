"""Pruebas de las metas de ahorro (RF-005).

El estado de una meta lo decide el servidor: completada cuando lo ahorrado
alcanza el objetivo, activa si no, y cancelada solo si el usuario la cancela.
"""

from decimal import Decimal

from tests.conftest import registrar_usuario

URL = "/api/v1/goals"


def meta(client, auth, **extra):
    cuerpo = {
        "nombre": "Vacaciones",
        "monto_objetivo": "5000000.00",
        "fecha_objetivo": "2027-01-15",
    }
    cuerpo.update(extra)
    r = client.post(URL, json=cuerpo, headers=auth)
    assert r.status_code == 201, r.text
    return r.json()


def test_una_meta_nueva_arranca_activa_y_en_cero(client, auth):
    m = meta(client, auth, descripcion="Viaje a Encarnación")
    assert m["estado"] == "activa"
    assert Decimal(m["monto_actual"]) == 0
    assert m["progreso"] == 0
    assert m["descripcion"] == "Viaje a Encarnación"


def test_el_progreso_es_el_porcentaje_ahorrado(client, auth):
    m = meta(client, auth, monto_actual="1250000.00")
    assert m["progreso"] == 25


def test_aportar_suma_a_lo_ahorrado(client, auth):
    m = meta(client, auth, monto_actual="1000000.00")
    r = client.post(f"{URL}/{m['id']}/aportar", json={"monto": "500000.00"}, headers=auth)
    assert r.status_code == 200
    assert Decimal(r.json()["monto_actual"]) == Decimal("1500000.00")
    assert r.json()["progreso"] == 30


def test_al_llegar_al_objetivo_se_completa_sola(client, auth):
    m = meta(client, auth, monto_actual="4000000.00")
    r = client.post(f"{URL}/{m['id']}/aportar", json={"monto": "1500000.00"}, headers=auth)
    assert r.json()["estado"] == "completada"
    # El progreso no pasa de 100 aunque se haya ahorrado de más.
    assert r.json()["progreso"] == 100


def test_crearla_ya_cumplida_la_deja_completada(client, auth):
    m = meta(client, auth, monto_actual="5000000.00")
    assert m["estado"] == "completada"


def test_subir_el_objetivo_de_una_completada_la_reactiva(client, auth):
    m = meta(client, auth, monto_actual="5000000.00")
    r = client.patch(f"{URL}/{m['id']}", json={"monto_objetivo": "8000000.00"}, headers=auth)
    assert r.json()["estado"] == "activa"
    assert r.json()["progreso"] == 62.5


def test_no_se_puede_marcar_completada_sin_juntar_la_plata(client, auth):
    m = meta(client, auth)
    r = client.patch(f"{URL}/{m['id']}", json={"estado": "completada"}, headers=auth)
    assert r.json()["estado"] == "activa"


def test_cancelar_y_reactivar(client, auth):
    m = meta(client, auth)
    r = client.patch(f"{URL}/{m['id']}", json={"estado": "cancelada"}, headers=auth)
    assert r.json()["estado"] == "cancelada"

    # A una meta cancelada no se le suma.
    r = client.post(f"{URL}/{m['id']}/aportar", json={"monto": "10.00"}, headers=auth)
    assert r.status_code == 409

    r = client.patch(f"{URL}/{m['id']}", json={"estado": "activa"}, headers=auth)
    assert r.json()["estado"] == "activa"


def test_editar_cambia_solo_lo_enviado(client, auth):
    m = meta(client, auth, descripcion="Viaje")
    r = client.patch(
        f"{URL}/{m['id']}",
        json={"nombre": "Vacaciones 2027", "fecha_objetivo": "2027-02-01"},
        headers=auth,
    )
    assert r.status_code == 200
    assert r.json()["nombre"] == "Vacaciones 2027"
    assert r.json()["fecha_objetivo"] == "2027-02-01"
    assert r.json()["descripcion"] == "Viaje"


def test_activas_primero_por_fecha_y_al_final_las_cerradas(client, auth):
    meta(client, auth, nombre="Lejana", fecha_objetivo="2028-01-01")
    meta(client, auth, nombre="Cumplida", fecha_objetivo="2026-01-01", monto_actual="5000000.00")
    meta(client, auth, nombre="Cercana", fecha_objetivo="2026-12-01")

    nombres = [m["nombre"] for m in client.get(URL, headers=auth).json()]
    assert nombres == ["Cercana", "Lejana", "Cumplida"]


def test_eliminar_una_meta(client, auth):
    m = meta(client, auth)
    assert client.delete(f"{URL}/{m['id']}", headers=auth).status_code == 204
    assert client.get(URL, headers=auth).json() == []


def test_montos_invalidos_son_rechazados(client, auth):
    for extra in ({"monto_objetivo": "0"}, {"monto_actual": "-1.00"}, {"nombre": ""}):
        cuerpo = {"nombre": "X", "monto_objetivo": "10.00", "fecha_objetivo": "2027-01-01"}
        cuerpo.update(extra)
        assert client.post(URL, json=cuerpo, headers=auth).status_code == 422

    m = meta(client, auth)
    r = client.post(f"{URL}/{m['id']}/aportar", json={"monto": "0"}, headers=auth)
    assert r.status_code == 422


def test_nadie_ve_ni_toca_metas_ajenas(client, auth):
    m = meta(client, auth)
    otro = registrar_usuario(client, email="beto@example.com", nombre="Beto")

    assert client.get(URL, headers=otro).json() == []
    assert client.patch(f"{URL}/{m['id']}", json={"nombre": "X"}, headers=otro).status_code == 404
    r = client.post(f"{URL}/{m['id']}/aportar", json={"monto": "1.00"}, headers=otro)
    assert r.status_code == 404
    assert client.delete(f"{URL}/{m['id']}", headers=otro).status_code == 404
    # La meta de Ana sigue intacta.
    assert client.get(URL, headers=auth).json()[0]["nombre"] == "Vacaciones"
