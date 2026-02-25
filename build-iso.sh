#!/usr/bin/env bash
set -euo pipefail

if ! command -v build-simple-cdd >/dev/null 2>&1; then
  echo "[ERROR] simple-cdd no está instalado. Instala: sudo apt install -y simple-cdd"
  exit 1
fi

source ./auto/config

ACTIVE_DIST="${ANARTZ_DIST}"
ACTIVE_SECURITY_MIRROR="${ANARTZ_SECURITY_MIRROR}"
ACTIVE_COMPONENTS="main contrib non-free non-free-firmware"

installer_initrd_url() {
  local dist="$1"
  printf '%sdists/%s/main/installer-%s/current/images/cdrom/initrd.gz' \
    "${ANARTZ_DEBIAN_MIRROR}" "${dist}" "${ANARTZ_ARCH}"
}

release_url() {
  local dist="$1"
  printf '%sdists/%s/Release' "${ANARTZ_DEBIAN_MIRROR}" "${dist}"
}

security_release_url() {
  local dist="$1"
  printf '%sdists/%s-security/Release' "${ANARTZ_SECURITY_MIRROR}" "${dist}"
}

# non-free-firmware existe a partir de bookworm. En bullseye rompe reprepro con undefinedtarget.
if [[ "${ACTIVE_DIST}" == "bullseye"* ]]; then
  ACTIVE_COMPONENTS="main contrib non-free"
fi

echo "[INFO] Comprobando mirrors de Debian para ${ACTIVE_DIST}..."

if ! curl -fsSLI "$(release_url "${ACTIVE_DIST}")" >/dev/null 2>&1; then
  echo "[WARN] Mirror principal no responde para ${ACTIVE_DIST}: $(release_url "${ACTIVE_DIST}")"
fi
if ! curl -fsSLI "$(installer_initrd_url "${ACTIVE_DIST}")" >/dev/null 2>&1; then
  echo "[WARN] No existe initrd cdrom para ${ACTIVE_DIST} en el mirror configurado."
  if [ -n "${ANARTZ_FALLBACK_DIST:-}" ]; then
    echo "[INFO] Aplicando fallback de compatibilidad simple-cdd -> ${ANARTZ_FALLBACK_DIST}"
    ACTIVE_DIST="${ANARTZ_FALLBACK_DIST}"
    ACTIVE_SECURITY_MIRROR="${ANARTZ_FALLBACK_SECURITY_MIRROR:-${ANARTZ_SECURITY_MIRROR}}"
    if [[ "${ACTIVE_DIST}" == "bullseye"* ]]; then
      ACTIVE_COMPONENTS="main contrib non-free"
    else
      ACTIVE_COMPONENTS="main contrib non-free non-free-firmware"
    fi
  fi
fi
if ! curl -fsSLI "$(security_release_url "${ACTIVE_DIST}")" >/dev/null 2>&1; then
  echo "[WARN] Mirror de seguridad no responde para ${ACTIVE_DIST}: $(security_release_url "${ACTIVE_DIST}")"
fi

echo "[INFO] Limpiando builds previas de simple-cdd..."
rm -rf tmp images simple-cdd/tmp simple-cdd/images simple-cdd/log .simple-cdd.active.conf 2>/dev/null || true

cp simple-cdd.conf .simple-cdd.active.conf
sed -i "s/^mirror_components=.*/mirror_components=\"${ACTIVE_COMPONENTS}\"/" .simple-cdd.active.conf

echo "[INFO] Componentes activos para ${ACTIVE_DIST}: ${ACTIVE_COMPONENTS}"

CMD=(
  build-simple-cdd
  --conf .simple-cdd.active.conf
  --profiles "${ANARTZ_PROFILES}"
  --dist "${ACTIVE_DIST}"
  --locale es_ES.UTF-8
  --keyboard es
  --auto-profiles "${ANARTZ_PROFILES}"
  --profiles-udeb-dist "${ACTIVE_DIST}"
  --force-root
)

if [ -n "${ANARTZ_DEBIAN_MIRROR:-}" ]; then
  CMD+=(--debian-mirror "${ANARTZ_DEBIAN_MIRROR}")
fi
if [ -n "${ACTIVE_SECURITY_MIRROR:-}" ]; then
  CMD+=(--security-mirror "${ACTIVE_SECURITY_MIRROR}")
fi

echo "[INFO] Construyendo ISO instalable (NO live) de Anartz OS con dist=${ACTIVE_DIST}..."
printf '[INFO] Comando: sudo'; printf ' %q' "${CMD[@]}"; printf '\n'

sudo "${CMD[@]}"

ISO_PATH="$(find . -maxdepth 4 -type f -name '*.iso' | head -n1 || true)"
if [ -n "${ISO_PATH}" ]; then
  cp -f "${ISO_PATH}" "${ANARTZ_ISO_NAME}"
  echo "[OK] ISO instalable generada: ${ANARTZ_ISO_NAME}"
else
  echo "[WARN] No encontré ninguna ISO tras la build; revisa logs en ./tmp/log/."
fi
