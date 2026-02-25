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

# non-free-firmware existe a partir de bookworm. En bullseye rompe reprepro con undefinedtarget.
if [[ "${ACTIVE_DIST}" == "bullseye"* ]]; then
  ACTIVE_COMPONENTS="main contrib non-free"
fi

echo "[INFO] Limpiando builds previas de simple-cdd..."
# tras builds con sudo, tmp/ y mirror quedan con owner root; limpiar sin sudo deja basura de reprepro.
sudo rm -rf tmp images simple-cdd/tmp simple-cdd/images simple-cdd/log .simple-cdd.active.conf 2>/dev/null || true
rm -rf tmp images simple-cdd/tmp simple-cdd/images simple-cdd/log .simple-cdd.active.conf 2>/dev/null || true

cp simple-cdd.conf .simple-cdd.active.conf
sed -i "s/^mirror_components=.*/mirror_components=\"${ACTIVE_COMPONENTS}\"/" .simple-cdd.active.conf

echo "[INFO] Componentes activos para ${ACTIVE_DIST}: ${ACTIVE_COMPONENTS}"

BASE_CMD=(
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
  BASE_CMD+=(--debian-mirror "${ANARTZ_DEBIAN_MIRROR}")
fi
if [ -n "${ACTIVE_SECURITY_MIRROR:-}" ]; then
  BASE_CMD+=(--security-mirror "${ACTIVE_SECURITY_MIRROR}")
fi

echo "[INFO] Paso 1/2: mirror-only para Anartz OS con dist=${ACTIVE_DIST}..."
printf '[INFO] Comando: sudo'; printf ' %q' "${BASE_CMD[@]}" --mirror-only; printf '\n'
sudo "${BASE_CMD[@]}" --mirror-only

EXPECTED_DIR="tmp/mirror/dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/cdrom"
EXPECTED_INITRD="${EXPECTED_DIR}/initrd.gz"
EXPECTED_KERNEL="${EXPECTED_DIR}/vmlinuz"

recover_file() {
  local target_path="$1"
  local filename="$2"
  local recovered=0

  if [ -f "${target_path}" ]; then
    return 0
  fi

  echo "[WARN] Falta ${filename} esperado: ${target_path}"
  mkdir -p "$(dirname "${target_path}")"

  local local_candidates=(
    "tmp/mirror/dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/netboot/debian-installer/${ANARTZ_ARCH}/${filename}"
    "tmp/mirror/dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/netboot/gtk/${filename}"
    "tmp/mirror/dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/hd-media/${filename}"
  )

  for local_candidate in "${local_candidates[@]}"; do
    if [ -f "${local_candidate}" ]; then
      cp -f "${local_candidate}" "${target_path}"
      echo "[INFO] ${filename} recuperado desde mirror local: ${local_candidate}"
      recovered=1
      break
    fi
  done

  if [ "${recovered}" -eq 0 ]; then
    local remote_candidates=(
      "${ANARTZ_DEBIAN_MIRROR}dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/netboot/debian-installer/${ANARTZ_ARCH}/${filename}"
      "${ANARTZ_DEBIAN_MIRROR}dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/netboot/gtk/${filename}"
      "${ANARTZ_DEBIAN_MIRROR}dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/hd-media/${filename}"
    )
    for remote_url in "${remote_candidates[@]}"; do
      if curl -fsSL "${remote_url}" -o "${target_path}"; then
        echo "[INFO] ${filename} recuperado descargando: ${remote_url}"
        recovered=1
        break
      fi
    done
  fi

  if [ "${recovered}" -eq 0 ]; then
    echo "[ERROR] No pude recuperar ${filename} para ${ACTIVE_DIST}."
    return 1
  fi

  return 0
}

recover_file "${EXPECTED_INITRD}" "initrd.gz"
recover_file "${EXPECTED_KERNEL}" "vmlinuz"

echo "[INFO] Paso 2/2: build-only para generar ISO instalable de Anartz OS..."
printf '[INFO] Comando: sudo'; printf ' %q' "${BASE_CMD[@]}" --build-only; printf '\n'
sudo "${BASE_CMD[@]}" --build-only

ISO_PATH="$(find . -maxdepth 4 -type f -name '*.iso' | head -n1 || true)"
if [ -n "${ISO_PATH}" ]; then
  cp -f "${ISO_PATH}" "${ANARTZ_ISO_NAME}"
  echo "[OK] ISO instalable generada: ${ANARTZ_ISO_NAME}"
else
  echo "[WARN] No encontré ninguna ISO tras la build; revisa logs en ./tmp/log/."
fi
