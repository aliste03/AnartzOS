#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] Ejecuta como root: sudo ./fix-installed-anartz.sh"
  exit 1
fi

WMSG='Bienvenido a Anartz os, desde aqui podras modificar el sistema y realizar cualquier accion mediante comandos, disfruta.'

echo "[INFO] Aplicando branding Anartz OS en sistema instalado..."

echo "[INFO] Instalando entorno gráfico KDE + SDDM (para Minecraft/CurseForge)..."
apt-get update || true
apt-get install -y sudo xorg xserver-xorg-video-all kde-plasma-desktop sddm plasma-desktop plasma-workspace mesa-vulkan-drivers || true

echo 'Anartz OS' > /etc/hostname
sed -i 's/^127.0.1.1.*/127.0.1.1\tAnartzOS/g' /etc/hosts || true

echo "$WMSG" > /etc/motd
echo "$WMSG" > /etc/issue
echo "$WMSG" > /etc/issue.net

for f in /etc/os-release /usr/lib/os-release; do
  [ -f "$f" ] || continue
  sed -i 's/Debian GNU\/Linux/Anartz OS/g' "$f" || true
  sed -i 's/^NAME=.*/NAME="Anartz OS"/' "$f" || true
  sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Anartz OS"/' "$f" || true
done

mkdir -p /etc/profile.d
echo 'export PS1="\[\e[38;5;25m\][\[\e[38;5;39m\]\u\[\e[38;5;25m\]@\[\e[97m\]AnartzOS\[\e[38;5;25m\]]\[\e[38;5;39m\]\w\[\e[97m\]\$ \[\e[0m\]"' > /etc/profile.d/anartz.sh
chmod 644 /etc/profile.d/anartz.sh

systemctl set-default graphical.target || true
systemctl enable sddm || true

if [ -f /etc/default/grub ]; then
  sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Anartz OS"/' /etc/default/grub || true
  update-grub || true
fi

echo "[OK] Branding aplicado. Reinicia para ver cambios en login/boot."
