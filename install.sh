#!/usr/bin/env bash
#
# install.sh - Instala un .jar de Java como servicio systemd en Linux.
#
# Uso:
#   sudo ./install.sh /ruta/a/miapp.jar
#
# Edita las variables de la sección CONFIG antes de usar.

set -euo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────
APP_NAME="uhf-sock"             
JAR_VERSION="R3-Reader-driver-1.0-unix.jar" 
SERVICE_USER="root"              
TMP_DIR="/tmp/${APP_NAME}"       
INSTALL_DIR="/opt/${APP_NAME}"  
JAVA_BIN="$(command -v java || echo /usr/bin/java)"
JAVA_OPTS="-Xms256m -Xmx512m"
APP_ARGS=""
GIT_TAG="v1.0.1"
# ────────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta este script con sudo/root." >&2
  exit 1
fi

# delete service if it exists
if [ -f "/etc/systemd/system/${APP_NAME}.service" ]; then
  echo "==> Deteniendo y eliminando servicio existente ${APP_NAME}."
  sudo journalctl --namespace=uhf-sock --vacuum-time=1s
  systemctl stop "${APP_NAME}.service" || true
  systemctl disable "${APP_NAME}.service" || true
  systemctl daemon-reload
  rm -f "/etc/systemd/system/${APP_NAME}.service"
  rm -rf "${INSTALL_DIR}"
  rm -rf "${TMP_DIR}"
fi

mkdir -p "${TMP_DIR}"
curl -L "https://raw.githubusercontent.com/softsolx-rfid/r3-driver/refs/tags/${GIT_TAG}/${JAR_VERSION}" -o "${TMP_DIR}/app.jar"

curl -L "https://raw.githubusercontent.com/softsolx-rfid/r3-driver/refs/tags/${GIT_TAG}/libTagReader.so" -o "${TMP_DIR}/libTagReader.so"

curl -L "https://raw.githubusercontent.com/softsolx-rfid/r3-driver/refs/tags/${GIT_TAG}/uhf-sock.service" -o "${TMP_DIR}/uhf-sock.service"

echo "==> Instalando ${APP_NAME} en ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
rm -f "${INSTALL_DIR}"/*
install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 640 "${TMP_DIR}/app.jar" "${INSTALL_DIR}/${APP_NAME}.jar"
install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 640 "${TMP_DIR}/libTagReader.so" "${INSTALL_DIR}/libTagReader.so"

echo "==> Escribiendo unidad systemd"
rm -f "/etc/systemd/system/${APP_NAME}.service"
install -o "$SERVICE_USER" -g "$SERVICE_USER" -m 644 "${TMP_DIR}/uhf-sock.service" "/etc/systemd/system/${APP_NAME}.service"

rm -rf "${TMP_DIR}"


echo "==> Recargando systemd y arrancando servicio"
systemctl daemon-reload
systemctl enable "${APP_NAME}.service"
systemctl restart "${APP_NAME}.service"

echo "==> Listo. Comandos útiles:"
echo "   systemctl status ${APP_NAME}"
echo "   journalctl -u ${APP_NAME} -f"