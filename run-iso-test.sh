#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-anartz-os-installable.iso}"
RAM_MB="${RAM_MB:-4096}"
CPUS="${CPUS:-4}"

if [ ! -f "$ISO_PATH" ]; then
  echo "[ERROR] No existe la ISO: $ISO_PATH"
  echo "Uso: $0 [ruta_iso]"
  exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "[ERROR] Falta QEMU. Instala: sudo apt install -y qemu-system-x86"
  exit 1
fi

echo "[INFO] Arrancando prueba NO destructiva de Anartz OS..."
echo "[INFO] Cierra la VM cuando termines de revisar el instalador/branding."

qemu-system-x86_64 \
  -enable-kvm \
  -m "$RAM_MB" \
  -smp "$CPUS" \
  -boot d \
  -cdrom "$ISO_PATH" \
  -display gtk \
  -vga virtio \
  -net nic -net user \
  -snapshot
