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
ACTIVE_NONFREE_COMPONENTS="non-free non-free-firmware"

# non-free-firmware existe a partir de bookworm. En bullseye rompe reprepro con undefinedtarget.
if [[ "${ACTIVE_DIST}" == "bullseye"* ]]; then
  ACTIVE_COMPONENTS="main contrib non-free"
  ACTIVE_NONFREE_COMPONENTS="non-free"
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
  --graphical-installer
  --force-root
)

if [ -n "${ANARTZ_DEBIAN_MIRROR:-}" ]; then
  BASE_CMD+=(--debian-mirror "${ANARTZ_DEBIAN_MIRROR}")
fi
if [ -n "${ACTIVE_SECURITY_MIRROR:-}" ]; then
  BASE_CMD+=(--security-mirror "${ACTIVE_SECURITY_MIRROR}")
fi

run_simple_cdd() {
  local mode="$1"
  local step
  step="${mode#--}"
  local logfile="tmp/log/anartz-${step}.log"

  mkdir -p tmp/log

  echo "[INFO] Comando: sudo env NONFREE_COMPONENTS=${ACTIVE_NONFREE_COMPONENTS}"
  printf '[INFO] build-simple-cdd'; printf ' %q' "${BASE_CMD[@]:1}" "${mode}"; printf '\n'
  echo "[INFO] Log en vivo: ${logfile}"

  set +e
  sudo env NONFREE_COMPONENTS="${ACTIVE_NONFREE_COMPONENTS}" "${BASE_CMD[@]}" "${mode}" \
    > >(tee -a "${logfile}") \
    2> >(grep -v "missing optional packages from profile default: usr-is-merged" | tee -a "${logfile}" >&2) &
  local cmd_pid=$!

  while kill -0 "${cmd_pid}" >/dev/null 2>&1; do
    sleep 30
    echo "[INFO] (${step}) sigue en ejecución... puedes ver progreso con: tail -f ${logfile}"
  done

  wait "${cmd_pid}"
  local rc=$?
  set -e

  if [ "${rc}" -ne 0 ]; then
    echo "[ERROR] build-simple-cdd ${mode} falló con código ${rc}."
    echo "[ERROR] Revisa log: ${logfile}"
    exit "${rc}"
  fi
}

echo "[INFO] Paso 1/2: mirror-only para Anartz OS con dist=${ACTIVE_DIST}..."
run_simple_cdd --mirror-only

EXPECTED_DIR="tmp/mirror/dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/cdrom"
EXPECTED_INITRD="${EXPECTED_DIR}/initrd.gz"
EXPECTED_KERNEL="${EXPECTED_DIR}/vmlinuz"
EXPECTED_GTK_DIR="${EXPECTED_DIR}/gtk"
EXPECTED_GTK_INITRD="${EXPECTED_GTK_DIR}/initrd.gz"
EXPECTED_GTK_KERNEL="${EXPECTED_GTK_DIR}/vmlinuz"


patch_initrd_branding() {
  local initrd_path="$1"
  [ -f "${initrd_path}" ] || return 0

  local workdir
  workdir="$(mktemp -d)"

  if (cd "${workdir}" && gzip -dc "${initrd_path}" | cpio -id --quiet) >/dev/null 2>&1; then
    local changed=0
    # Cambiar textos Debian -> Anartz OS en archivos de texto del initrd del instalador.
    while IFS= read -r -d '' file; do
      if file --mime "${file}" 2>/dev/null | grep -q 'charset=binary'; then
        continue
      fi
      if rg -q "Debian" "${file}"; then
        sed -i 's/Debian/Anartz OS/g' "${file}" || true
        changed=1
      fi
      if rg -q "debian" "${file}"; then
        sed -i 's/debian/AnartzOS/g' "${file}" || true
        changed=1
      fi
    done < <(find "${workdir}" -type f -print0)

    if [ "${changed}" -eq 1 ]; then
      (cd "${workdir}" && find . -print0 | cpio --null -o -H newc --quiet | gzip -9 > "${initrd_path}")
      echo "[INFO] Branding textual aplicado en initrd: ${initrd_path}"
    fi
  fi

  rm -rf "${workdir}"
}

recover_file() {
  local target_path="$1"
  local filename="$2"
  local allow_stub="${3:-0}"
  local recovered=0

  if [ -f "${target_path}" ]; then
    return 0
  fi

  echo "[WARN] Falta ${filename} esperado: ${target_path}"
  mkdir -p "$(dirname "${target_path}")"

  local local_candidates=(
    "tmp/mirror/dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/cdrom/${filename}"
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
      "${ANARTZ_DEBIAN_MIRROR}dists/${ACTIVE_DIST}/main/installer-${ANARTZ_ARCH}/current/images/cdrom/${filename}"
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

  if [ "${recovered}" -eq 0 ] && [ "${allow_stub}" = "1" ] && [ "${filename}" = "debian-cd_info.tar.gz" ]; then
    echo "[WARN] No encontré ${filename} en mirror; generando tarball mínimo de compatibilidad."
    local tmpd
    tmpd="$(mktemp -d)"
    tar -C "${tmpd}" -czf "${target_path}" .
    rm -rf "${tmpd}"
    recovered=1
  fi

  if [ "${recovered}" -eq 0 ]; then
    echo "[ERROR] No pude recuperar ${filename} para ${ACTIVE_DIST}."
    return 1
  fi

  return 0
}

recover_file "${EXPECTED_INITRD}" "initrd.gz"
recover_file "${EXPECTED_KERNEL}" "vmlinuz"
recover_file "${EXPECTED_GTK_INITRD}" "initrd.gz"
recover_file "${EXPECTED_GTK_KERNEL}" "vmlinuz"
recover_file "${EXPECTED_DIR}/debian-cd_info.tar.gz" "debian-cd_info.tar.gz" "1"

patch_initrd_branding "${EXPECTED_INITRD}"
patch_initrd_branding "${EXPECTED_GTK_INITRD}"

echo "[INFO] Paso 2/2: build-only para generar ISO instalable de Anartz OS..."
run_simple_cdd --build-only

ISO_PATH="$(find . -maxdepth 4 -type f -name '*.iso' | head -n1 || true)"
if [ -n "${ISO_PATH}" ]; then
  cp -f "${ISO_PATH}" "${ANARTZ_ISO_NAME}"
  echo "[OK] ISO instalable generada: ${ANARTZ_ISO_NAME}"
else
  echo "[WARN] No encontré ninguna ISO tras la build; revisa logs en ./tmp/log/."
fi
