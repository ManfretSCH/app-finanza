#!/usr/bin/env bash
#
# Genera el APK para repartir al equipo, apuntando al backend que corre en
# esta maquina.
#
# La direccion se fija al compilar, asi que hay que volver a generar el APK
# cada vez que cambie la IP (al cambiar de red, o si el router la reasigna).
#
#   ./scripts/apk-para-el-equipo.sh                                  IP detectada
#   ./scripts/apk-para-el-equipo.sh 10.0.0.7                         una IP
#   ./scripts/apk-para-el-equipo.sh https://finanzas-api.onrender.com  el backend desplegado
#
set -euo pipefail

cd "$(dirname "$0")/.."

# Se puede pasar una URL completa (el backend desplegado) o una IP (red local).
ENTRADA="${1:-}"

if [[ "$ENTRADA" == http://* || "$ENTRADA" == https://* ]]; then
  URL="${ENTRADA%/}"
  [[ "$URL" == */api/v1 ]] || URL="${URL}/api/v1"
else
  IP="${ENTRADA:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)}"
fi

if [ -z "${URL:-}" ]; then
  if [ -z "${IP:-}" ]; then
    echo "No se pudo detectar la IP de esta maquina en la red local."
    echo "Pasa una IP o la URL del backend desplegado:"
    echo "  ./scripts/apk-para-el-equipo.sh 192.168.0.5"
    echo "  ./scripts/apk-para-el-equipo.sh https://finanzas-api.onrender.com"
    exit 1
  fi
  URL="http://${IP}:8000/api/v1"
fi
echo "Compilando el APK contra ${URL}"
echo

cd mobile
# Las compilaciones de release no permiten trafico sin cifrar. Si el backend
# todavia esta en HTTP (por ejemplo en la red local), se compila en modo
# depuracion, que si lo permite: pesa mas y va mas lento, pero funciona.
if [[ "$URL" == https://* ]]; then
  MODO="--release"
  echo "Backend por HTTPS: se compila en modo release."
else
  MODO="--debug"
  echo "Backend por HTTP sin cifrar: se compila en modo depuracion, porque"
  echo "Android bloquea el trafico en claro en las compilaciones de release."
fi

# Se excluye x86_64, que solo la usan los emuladores: son 20 MB que ningun
# telefono real necesita. Quedan arm64 (todo lo moderno) y arm de 32 bits
# (equipos viejos). Para probar en un emulador conviene usar flutter run.
flutter build apk $MODO \
  --target-platform android-arm,android-arm64 \
  --dart-define="API_URL=${URL}"

DESTINO="../build-equipo"
mkdir -p "$DESTINO"
cp build/app/outputs/flutter-apk/app-release.apk "$DESTINO/mis-finanzas.apk"

cat > "$DESTINO/COMO-PROBAR.txt" <<TXT
MIS FINANZAS - version de prueba
=================================

Que necesitas
-------------
1. Un telefono Android.
2. Estar conectado a la MISMA red Wi-Fi que la computadora donde corre el
   servidor. Con datos moviles no funciona.
3. Que esa computadora tenga el servidor encendido. Si no, la app abre pero
   dice que no se pudo conectar.

Como instalarlo
---------------
1. Copia el archivo mis-finanzas.apk al telefono (WhatsApp, correo, cable).
2. Abrilo desde el telefono.
3. Android va a avisar que la app viene de un origen desconocido. Es normal:
   la app no esta publicada en Play Store todavia. Hay que permitir la
   instalacion desde esa aplicacion.
4. Instalar y abrir.

Primera vez
-----------
Toca "No tengo cuenta, quiero registrarme" y crea tu usuario. Cada uno ve
solo sus propios datos.

Despues:
- Crea una cuenta (caja de ahorro, efectivo, tarjeta...) con su saldo inicial.
- Carga algunos ingresos y gastos desde Movimientos.
- Mira la pestana Informes.

Si dice que no se pudo conectar
-------------------------------
- Confirma que estas en la misma Wi-Fi que la computadora del servidor.
- Confirma con quien tiene el servidor que lo dejo encendido.
- Si cambiaron de red (por ejemplo de la facultad a la casa), la direccion
  cambio y hace falta un APK nuevo.

Este APK apunta a: ${URL}
Generado el $(date '+%d/%m/%Y a las %H:%M')
TXT

echo
echo "Listo. En $(cd "$DESTINO" && pwd):"
ls -la "$DESTINO"
