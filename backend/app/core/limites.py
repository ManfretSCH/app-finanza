"""Limite de intentos de inicio de sesion.

Sin esto, cualquiera puede probar contrasenas contra la API todo el dia. Con
el servidor en la red local no era urgente; publicado en internet, si.

Es un contador en memoria del propio proceso. Alcanza para este proyecto, que
corre en una sola instancia, pero conviene saber sus limites: se reinicia
cuando se reinicia el servidor, y si algun dia se levantan varias instancias
cada una llevaria su propia cuenta. La version robusta usaria Redis.
"""

from collections import defaultdict
from datetime import UTC, datetime, timedelta

from app.core.config import settings

# IP -> momentos en que fallo un intento
_intentos_fallidos: dict[str, list[datetime]] = defaultdict(list)


def _ahora() -> datetime:
    return datetime.now(UTC)


def _limpiar_viejos(ip: str) -> list[datetime]:
    """Descarta los intentos anteriores a la ventana y devuelve los que siguen contando."""
    limite = _ahora() - timedelta(minutes=settings.VENTANA_LOGIN_MINUTOS)
    vigentes = [t for t in _intentos_fallidos[ip] if t > limite]
    _intentos_fallidos[ip] = vigentes
    return vigentes


def esta_bloqueada(ip: str) -> bool:
    return len(_limpiar_viejos(ip)) >= settings.INTENTOS_LOGIN_MAXIMOS


def registrar_fallo(ip: str) -> None:
    _limpiar_viejos(ip)
    _intentos_fallidos[ip].append(_ahora())


def limpiar(ip: str) -> None:
    """Se llama al iniciar sesion bien: un acierto borra los fallos previos."""
    _intentos_fallidos.pop(ip, None)


def reiniciar() -> None:
    """Solo para las pruebas."""
    _intentos_fallidos.clear()
