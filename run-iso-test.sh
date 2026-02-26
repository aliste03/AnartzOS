#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-anartz-os-installable.iso}"
RAM_MB="${RAM_MB:-4096}"
CPUS="${CPUS:-4}"
TEST_DISK_GB="${TEST_DISK_GB:-40}"

if [ ! -f "$ISO_PATH" ]; then
  echo "[ERROR] No existe la ISO: $ISO_PATH"
  echo "Uso: $0 [ruta_iso]"
  exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "[ERROR] Falta QEMU. Instala: sudo apt install -y qemu-system-x86 qemu-utils"
  exit 1
fi

if ! command -v qemu-img >/dev/null 2>&1; then
  echo "[ERROR] Falta qemu-img. Instala: sudo apt install -y qemu-utils"
  exit 1
fi

TMP_DISK="$(mktemp -u /tmp/anartz-vm-XXXXXX.qcow2)"
qemu-img create -f qcow2 "$TMP_DISK" "${TEST_DISK_GB}G" >/dev/null

cleanup() {
  rm -f "$TMP_DISK"
}
trap cleanup EXIT

echo "[INFO] Arrancando prueba NO destructiva de Anartz OS..."
echo "[INFO] Disco temporal VM: $TMP_DISK (${TEST_DISK_GB}G)"
echo "[INFO] Forzando arranque desde ISO (orden d, menú visible)."
echo "[INFO] Cierra la VM cuando termines de revisar instalador/branding."

qemu-system-x86_64 \
  -enable-kvm \
  -m "$RAM_MB" \
  -smp "$CPUS" \
  -boot order=d,menu=on \
  -drive file="$TMP_DISK",if=virtio,format=qcow2 \
  -cdrom "$ISO_PATH" \
  -display gtk \
  -vga virtio \
  -net nic -net user \
  -snapshot
