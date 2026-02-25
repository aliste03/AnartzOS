#!/usr/bin/env bash
set -euo pipefail

if ! command -v build-simple-cdd >/dev/null 2>&1; then
  echo "[ERROR] simple-cdd no está instalado. Instala: sudo apt install -y simple-cdd"
  exit 1
fi

source ./auto/config

echo "[INFO] Comprobando mirrors de Debian..."

# Sanity check rápido de mirrors (evita fallos tipo "No packages found")
for u in "${ANARTZ_DEBIAN_MIRROR}dists/${ANARTZ_DIST}/Release" "${ANARTZ_SECURITY_MIRROR}dists/${ANARTZ_DIST}-security/Release"; do
  if ! curl -fsSLI "$u" >/dev/null 2>&1; then
    echo "[WARN] No pude validar mirror: $u"
  fi
done

echo "[INFO] Limpiando builds previas de simple-cdd..."
rm -rf simple-cdd/tmp simple-cdd/images simple-cdd/log images 2>/dev/null || true

CMD=(
  build-simple-cdd
  --conf simple-cdd.conf
  --profiles "${ANARTZ_PROFILES}"
  --dist "${ANARTZ_DIST}"
  --locale es_ES.UTF-8
  --keyboard es
  --auto-profiles "${ANARTZ_PROFILES}"
  --profiles-udeb-dist "${ANARTZ_DIST}"
  --force-root
)

# Compatibilidad entre versiones: solo añade mirrors si están definidos.
if [ -n "${ANARTZ_DEBIAN_MIRROR:-}" ]; then
  CMD+=(--debian-mirror "${ANARTZ_DEBIAN_MIRROR}")
fi
if [ -n "${ANARTZ_SECURITY_MIRROR:-}" ]; then
  CMD+=(--security-mirror "${ANARTZ_SECURITY_MIRROR}")
fi

echo "[INFO] Construyendo ISO instalable (NO live) de Anartz OS..."
printf '[INFO] Comando: sudo'; printf ' %q' "${CMD[@]}"; printf '\n'

sudo "${CMD[@]}"

ISO_PATH="$(find . -maxdepth 4 -type f -name '*.iso' | head -n1 || true)"
if [ -n "${ISO_PATH}" ]; then
  cp -f "${ISO_PATH}" "${ANARTZ_ISO_NAME}"
  echo "[OK] ISO instalable generada: ${ANARTZ_ISO_NAME}"
else
  echo "[WARN] No encontré ninguna ISO tras la build; revisa logs de simple-cdd."
fi
