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


## Error: `No packages found` / `debian_mirror ... does not end in '/'`

Se corrigió la configuración para usar mirrors con **HTTPS** y barra final (`/`):

- `https://deb.debian.org/debian/`
- `https://security.debian.org/debian-security/`

Además `build-iso.sh` ahora:
- valida mirrors al inicio;
- fija `--profiles-udeb-dist` con la distro activa;
- imprime el comando exacto antes de ejecutar.

Si te vuelve a pasar, limpia y relanza:

```bash
rm -rf tmp images simple-cdd/tmp simple-cdd/images simple-cdd/log
./build-iso.sh
```


## Compatibilidad simple-cdd en Kali (fallback automático)

En algunos Kali/simple-cdd, `bookworm` falla con:

- `E: No packages found`
- `... installer-amd64 ... initrd.gz: No such file or directory`

Para evitarlo, `build-iso.sh` ahora verifica si existe `installer-amd64/current/images/cdrom/initrd.gz` para la distro activa y, si no existe, aplica fallback a la distro definida en `ANARTZ_FALLBACK_DIST`.

Actualmente la configuración por defecto arranca en `bullseye` (más compatible en Kali) y deja `bookworm` como fallback.

Puedes forzarlo manualmente editando `auto/config`:

```bash
export ANARTZ_DIST="bullseye"
export ANARTZ_FALLBACK_DIST="bookworm"
```


## Error `reprepro ... undefinedtarget` en Kali

Si aparece ese error al usar `bullseye`, normalmente es por componentes no válidos para esa release.

- `bullseye` **no** usa `non-free-firmware`.
- El script ahora ajusta componentes automáticamente:
  - `bullseye` -> `main contrib non-free`
  - `bookworm+` -> `main contrib non-free non-free-firmware`

Además genera una conf temporal `.simple-cdd.active.conf` con los componentes correctos para la distro activa.


Si el error persiste, fuerza limpieza de artefactos root antes de relanzar:

```bash
sudo rm -rf tmp images simple-cdd/tmp simple-cdd/images simple-cdd/log .simple-cdd.active.conf
./build-iso.sh
```


## Recuperación automática de initrd (error `cp: cannot stat ... images/cdrom/initrd.gz`)

Algunos mirrors/distros no exponen `images/cdrom/initrd.gz` directamente para `simple-cdd`/`debian-cd`.

`build-iso.sh` ahora ejecuta en dos fases:
1. `--mirror-only`
2. `--build-only`

Entre ambas, si faltan `.../images/cdrom/initrd.gz`, `.../images/cdrom/vmlinuz` o `.../images/cdrom/debian-cd_info.tar.gz`, intenta recuperarlos desde:
- netboot local ya espejado, o
- descarga directa desde rutas `netboot/` o `hd-media/` del mirror,

y los coloca en las rutas esperadas por `debian-cd`.

Si `debian-cd_info.tar.gz` no existe en ninguna ruta del mirror, genera un tarball mínimo de compatibilidad para no bloquear el proceso.


## Error `NONFREE_COMPONENTS` no inicializada / falta `cdrom/gtk/vmlinuz`

En algunos entornos, `debian-cd` requiere `NONFREE_COMPONENTS` y también ficheros en `images/cdrom/gtk/`.

El script ahora:
- ejecuta `build-simple-cdd` con `NONFREE_COMPONENTS` acorde a la distro activa;
- recupera también `images/cdrom/gtk/initrd.gz` y `images/cdrom/gtk/vmlinuz` en la fase de parcheo.


## Si ya instalaste y no salió el branding Anartz OS

Ejecuta el script de corrección en el sistema instalado:

```bash
sudo ./fix-installed-anartz.sh
reboot
```

Esto aplica hostname, `/etc/os-release`, `motd/issue`, prompt y GRUB con marca `Anartz OS`, y además instala/habilita KDE+SDDM si faltan.


## Entorno gráfico garantizado (KDE)

La instalación ahora fuerza paquetes de escritorio (`kde-plasma-desktop`, `xorg`, `sddm`) y deja el sistema en `graphical.target` con `sddm` habilitado, para que arranque en interfaz gráfica (ideal para Minecraft/CurseForge).


## Instalador gráfico estilo Anartz OS

El preseed ahora fuerza frontend gráfico (`gtk`) y añade parámetros de título/colores para instalador:
- título: `Anartz OS`
- estilo solicitado: fondo oscuro y texto blanco.

> Nota: Debian Installer puede ignorar parte del theming según hardware/controlador gráfico; pero con esta configuración intenta usar instalador gráfico GTK y branding Anartz OS arriba.


Además del preseed GTK, la build ahora parchea texto dentro del `initrd` del instalador (`Debian` -> `Anartz OS`) para reforzar branding durante la instalación.


## Nota sobre warning `usr-is-merged`

En builds con bullseye, simple-cdd puede emitir el warning opcional:
`missing optional packages from profile default: usr-is-merged`.

El script ahora filtra esa línea concreta para que no ensucie la salida, ya que no bloquea la generación de la ISO.


## Si parece que la build está "bloqueada"

`--mirror-only` puede tardar bastante tiempo sin mucho output en algunas redes.

Ahora el script muestra heartbeat cada 30s y escribe log en:
- `tmp/log/anartz-mirror-only.log`
- `tmp/log/anartz-build-only.log`

Puedes seguirlo en vivo con:

```bash
tail -f tmp/log/anartz-mirror-only.log
```


## Instalador gráfico (compatibilidad por versión)

Algunas versiones de `build-simple-cdd` no soportan `--graphical-installer` (como en Kali).

Por compatibilidad, el repo fuerza instalador gráfico desde preseed (`debian-installer/gui`, `cdebconf/frontend=gtk`) en lugar de usar ese flag.


## Sobre run-iso-test.sh y el instalador

Sí, podía influir si no quedaba forzado el arranque desde ISO o no había disco virtual limpio para instalar.

Ahora `run-iso-test.sh`:
- crea un disco QCOW2 temporal;
- fuerza `-boot order=d,menu=on`;
- borra el disco temporal al salir.

Así siempre pruebas el instalador desde cero y evitas confusiones con arranques previos.
