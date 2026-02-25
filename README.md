# Anartz OS ISO Builder (Instalable, NO Live)

Este repositorio genera una **ISO instalable** basada en Debian llamada **Anartz OS**.

Objetivo de la distro:
- gestión de páginas web y servidores dedicados;
- gaming (Minecraft/CurseForge), compatibilidad NVIDIA;
- estilo visual hacking (azul oscuro brillante, negro y blanco);
- branding completo como **Anartz OS**.

## Tipo de imagen

Este proyecto usa **simple-cdd** para crear una ISO del instalador de Debian (**instalable**, no live session).

## Qué personaliza

- Branding del sistema a `Anartz OS` en hostname, `/etc/os-release`, GRUB y mensajes de login.
- Mensaje de bienvenida en terminal:
  - `Bienvenido a Anartz os, desde aqui podras modificar el sistema y realizar cualquier accion mediante comandos, disfruta.`
- Prompt y colores oscuros/azules para terminal.
- Tema Plymouth con animación de brillo lateral para mostrar `Anartz OS` al arranque.
- Stack de paquetes para web/server y gaming + NVIDIA.
- Instalación de Opera (repo oficial opera-stable).
- Renombrado del usuario UID 0 de `root` a `Anartz` (requisito explícito).

## Requisitos

```bash
sudo apt update
sudo apt install -y simple-cdd debootstrap xorriso squashfs-tools curl gnupg ca-certificates
```

## Construcción de la ISO instalable

```bash
chmod +x build-iso.sh
./build-iso.sh
```

La salida principal se copia como:

- `anartz-os-installable.iso`

## Estructura clave

- `build-iso.sh`: orquestador de build con simple-cdd.
- `auto/config`: variables de distribución/arquitectura/perfil/mirrors.
- `simple-cdd.conf`: configuración base de simple-cdd.
- `simple-cdd/profiles/anartz.packages`: paquetes incluidos.
- `simple-cdd/profiles/anartz.preseed`: automatización del instalador y branding post-instalación.


## Probar la ISO sin instalar en tu PC

Puedes probarla en una VM desde tu entorno gráfico Linux sin tocar tu disco real.

### Opción rápida (QEMU con ventana gráfica)

Instala QEMU:

```bash
sudo apt install -y qemu-system-x86
```

Lanza la prueba:

```bash
chmod +x run-iso-test.sh
./run-iso-test.sh anartz-os-installable.iso
```

Esto abre una ventana con el instalador de **Anartz OS** y modo `-snapshot` (no persistente).

### Qué revisar en la prueba

- Que arranque el instalador (ISO instalable, no live).
- Que el branding indique `Anartz OS`.
- Que el flujo de instalación llegue hasta el particionado sin errores.
- Tras instalación en disco virtual, validar mensaje terminal, tema y paquetes.


## Solución de error común en Kali

Si ves este error:

```
build-simple-cdd: error: ambiguous option: --mirror
```

usa esta versión del script (ya corregida) que llama a:

- `--debian-mirror` (en lugar de `--mirror`)

Luego repite:

```bash
./build-iso.sh
```


## Si sigue saliendo `ambiguous option: --mirror`

Eso significa que estás ejecutando una copia vieja del script o un comando distinto.

Comprueba rápidamente:

```bash
pwd
head -n 40 ./build-iso.sh
```

Debe verse `--debian-mirror` y **no** `--mirror`.

También puedes verificar:

```bash
grep -n -- "--mirror" ./build-iso.sh || echo "OK: sin --mirror"
```

Luego ejecuta:

```bash
./build-iso.sh
```
