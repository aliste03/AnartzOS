#!/usr/bin/env bash
set -euo pipefail

if ! command -v build-simple-cdd >/dev/null 2>&1; then
  echo "[ERROR] simple-cdd no está instalado. Instala: sudo apt install -y simple-cdd"
  exit 1
fi

source ./auto/config

echo "[INFO] Limpiando builds previas de simple-cdd..."
rm -rf simple-cdd/tmp simple-cdd/images simple-cdd/log images 2>/dev/null || true

echo "[INFO] Construyendo ISO instalable (NO live) de Anartz OS..."
sudo build-simple-cdd \
  --conf simple-cdd.conf \
  --profiles "${ANARTZ_PROFILES}" \
  --dist "${ANARTZ_DIST}" \
  --locale es_ES.UTF-8 \
  --keyboard es \
  --debian-mirror "${ANARTZ_DEBIAN_MIRROR}" \
  --security-mirror "${ANARTZ_SECURITY_MIRROR}" \
  --auto-profiles "${ANARTZ_PROFILES}" \
  --force-root

ISO_PATH="$(find . -maxdepth 3 -type f -name '*.iso' | head -n1 || true)"
if [ -n "${ISO_PATH}" ]; then
  cp -f "${ISO_PATH}" "${ANARTZ_ISO_NAME}"
  echo "[OK] ISO instalable generada: ${ANARTZ_ISO_NAME}"
else
  echo "[WARN] No encontré ninguna ISO tras la build; revisa logs de simple-cdd."
fi
