#!/usr/bin/env bash
# ==============================================================================
# FEDORA 45 KDE SPIN -> DEBLOAT + APLICACIONES
# Objetivo: HP Celeron N4020 / Intel UHD 600 / 8 GB RAM / SSD 256 GB
#
# Ejecutar DESPUES de instalar Fedora 45 KDE Plasma Desktop (spin):
#   chmod +x fedora45-kde-spin-debloat.sh
#   sudo ./fedora45-kde-spin-debloat.sh
#
# Diferencias frente al script para Everything:
#   - No instala Plasma (el spin ya lo trae); solo lo verifica.
#   - La sección de limpieza es más amplia y usa una GUARDA: antes de eliminar,
#     simula la transacción con DNF y la cancela si arrastraría componentes
#     críticos del escritorio (plasma-desktop, kwin, sddm, etc.).
#   - Nunca se usa "dnf group remove" ni "dnf autoremove".
#
# Las operaciones opcionales que fallen quedan registradas y no abortan todo.
# Las operaciones esenciales si fallan detienen el script.
# ==============================================================================

set -Eeuo pipefail
umask 022

VERDE='\033[0;32m'
AZUL='\033[1;34m'
AMARILLO='\033[1;33m'
ROJO='\033[0;31m'
NC='\033[0m'

if [[ ${EUID} -ne 0 ]]; then
    echo -e "${ROJO}Ejecuta con sudo: sudo $0${NC}"
    exit 1
fi

REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    REAL_USER="$(logname 2>/dev/null || true)"
fi
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    echo -e "${ROJO}No pude identificar al usuario normal. Ejecuta el script desde tu cuenta usando sudo.${NC}"
    exit 1
fi

USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    echo -e "${ROJO}No pude determinar el HOME de $REAL_USER.${NC}"
    exit 1
fi

LOG_FILE="$USER_HOME/fedora_kde_spin_debloat.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

ok() {
    echo -e "${VERDE}[OK] $*${NC}"
    log "OK: $*"
}

warn() {
    echo -e "${AMARILLO}[AVISO] $*${NC}"
    log "AVISO: $*"
}

fail() {
    echo -e "${ROJO}[ERROR] $*${NC}"
    log "ERROR: $*"
}

# Ejecuta una operación esencial. Si falla, se detiene para no dejar
# una instalación a medias y seguir aplicando cambios peligrosos.
critical() {
    local description="$1"
    shift
    echo -e "${AZUL}==> $description${NC}"
    if "$@" >>"$LOG_FILE" 2>&1; then
        ok "$description"
    else
        local rc=$?
        fail "$description (código $rc). Revisa $LOG_FILE"
        exit "$rc"
    fi
}

# Ejecuta una operación opcional. Un fallo queda registrado y el script sigue.
optional() {
    local description="$1"
    shift
    echo -e "${AZUL}==> $description${NC}"
    if "$@" >>"$LOG_FILE" 2>&1; then
        ok "$description"
    else
        local rc=$?
        warn "$description no se pudo completar (código $rc). Se continúa."
    fi
}

# Copia de seguridad antes de modificar configuraciones existentes.
backup_file() {
    local file="$1"
    if [[ -e "$file" ]]; then
        cp -a "$file" "${file}.bak.$(date +%Y%m%d-%H%M%S)"
    fi
}

# Ejecuta comandos como el usuario de escritorio sin anidar sudo.
as_user() {
    runuser -u "$REAL_USER" -- "$@"
}

# Instala un conjunto de paquetes. --skip-unavailable permite que un nombre
# opcional ausente en los repositorios no cancele toda la transacción.
dnf_install() {
    /usr/bin/dnf install -y --skip-unavailable "$@"
}

# ------------------------------------------------------------------------------
# Eliminación segura con guarda
# ------------------------------------------------------------------------------
# Paquetes que NUNCA deben quedar dentro de una transacción de eliminación.
# Si DNF los arrastra como dependientes, la eliminación se cancela.
PROTECTED=(
    plasma-desktop plasma-workspace plasma-workspace-wayland kwin kwin-wayland
    sddm sddm-breeze sddm-wayland-plasma plasma-login-manager kcm-plasmalogin
    dolphin konsole systemsettings plasma-nm plasma-pa kscreen kscreenlocker
    bluedevil plasma-systemmonitor xdg-desktop-portal-kde
    fedora-release-kde fedora-release-identity-kde kde-settings kde-settings-plasma
    NetworkManager NetworkManager-wifi pipewire wireplumber bluez
    systemd dnf dnf5 sudo kernel kernel-core firewalld
)

# Devuelve (por stdout) los paquetes protegidos que aparecen en la simulación.
# Se compara el primer campo de cada línea con coincidencia exacta.
protected_in_plan() {
    local plan="$1"
    printf '%s\n' "$plan" | awk 'NF {print $1}' \
        | grep -Fx -f <(printf '%s\n' "${PROTECTED[@]}") || true
}

# Simula la eliminación de los paquetes dados y devuelve el plan por stdout.
# --assumeno devuelve código distinto de 0 a propósito; se ignora.
simulate_remove() {
    /usr/bin/dnf remove --assumeno \
        --setopt=clean_requirements_on_remove=False "$@" 2>&1 || true
}

# Elimina solamente paquetes realmente instalados, con guarda de seguridad.
# 1) Intenta todo el lote. 2) Si el lote toca algo protegido, evalúa paquete
#    por paquete y elimina únicamente los que son seguros.
remove_safely() {
    local installed=()
    local pkg
    for pkg in "$@"; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
            installed+=("$pkg")
        fi
    done

    if ((${#installed[@]} == 0)); then
        echo "No hay paquetes de la lista instalados; nada que eliminar."
        return 0
    fi

    echo "Instalados y candidatos a eliminar: ${installed[*]}"

    local plan blocked
    plan="$(simulate_remove "${installed[@]}")"
    blocked="$(protected_in_plan "$plan")"

    if [[ -z "$blocked" ]]; then
        /usr/bin/dnf remove -y --setopt=clean_requirements_on_remove=False \
            "${installed[@]}"
        return 0
    fi

    echo "El lote completo arrastraría paquetes protegidos:"
    echo "$blocked"
    echo "Evaluando paquete por paquete..."

    local safe=()
    for pkg in "${installed[@]}"; do
        plan="$(simulate_remove "$pkg")"
        blocked="$(protected_in_plan "$plan")"
        if [[ -z "$blocked" ]]; then
            safe+=("$pkg")
        else
            echo "OMITIDO (arrastraría: $(echo "$blocked" | tr '\n' ' ')): $pkg"
        fi
    done

    if ((${#safe[@]})); then
        /usr/bin/dnf remove -y --setopt=clean_requirements_on_remove=False \
            "${safe[@]}"
    else
        echo "Ningún paquete del lote es seguro de eliminar."
    fi
}

echo -e "${AZUL}============================================================${NC}"
echo -e "${AZUL} FEDORA 45 KDE SPIN - DEBLOAT${NC}"
echo -e "${AZUL} Usuario: $REAL_USER | Equipo objetivo: Celeron N4020 / 8 GB${NC}"
echo -e "${AZUL}============================================================${NC}"

{
    echo "=== FEDORA 45 KDE SPIN DEBLOAT ==="
    echo "Fecha: $(date)"
    echo "Usuario: $REAL_USER"
    echo "HOME: $USER_HOME"
    echo "Kernel: $(uname -r)"
    echo "Fedora: $(rpm -E %fedora)"
    echo "--- Paquetes instalados antes de empezar ---"
    rpm -qa --qf '%{NAME}\n' | sort
    echo "--- Fin lista inicial ---"
} >"$LOG_FILE"

# ==============================================================================
# 0. VALIDACIONES
# ==============================================================================
if [[ "$(rpm -E %fedora)" != "45" ]]; then
    warn "Este script fue preparado para Fedora 45; detectado Fedora $(rpm -E %fedora)."
    read -r -p "¿Continuar de todas formas? [s/N]: " confirm < /dev/tty || confirm="n"
    [[ "$confirm" =~ ^[sS]$ ]] || exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
    fail "No se encontró DNF."
    exit 1
fi

if ! rpm -q plasma-desktop >/dev/null 2>&1; then
    fail "No detecto plasma-desktop. Este script es para el KDE Spin ya instalado."
    fail "Si partiste de Everything, usa el script fedora45-everything-kde-minimo.sh."
    exit 1
fi

# Fedora 44+ cambió SDDM por Plasma Login Manager (plasmalogin.service) en las
# variantes KDE. Se detecta cuál está instalado en lugar de asumir uno.
DM_SERVICE=""
if rpm -q plasma-login-manager >/dev/null 2>&1; then
    DM_SERVICE="plasmalogin.service"
elif rpm -q sddm >/dev/null 2>&1; then
    DM_SERVICE="sddm.service"
else
    fail "No detecto ningún login manager (plasma-login-manager ni sddm)."
    exit 1
fi
log "Login manager detectado: $DM_SERVICE"

# ==============================================================================
# 1. DNF Y REPOSITORIOS
# ==============================================================================
echo -e "${AZUL}1. Configurando repositorios...${NC}"

critical "Instalar herramientas de repositorios y Flatpak" \
    dnf_install dnf-plugins-core flatpak curl

optional "Agregar RPM Fusion Free y Nonfree" bash -c '
    set -e
    fedora="$(rpm -E %fedora)"
    dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora}.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora}.noarch.rpm"
'

optional "Agregar Flathub para todos los usuarios" \
    /usr/bin/flatpak remote-add --system --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

optional "Agregar repositorio oficial de Tailscale" bash -c '
    set -e
    curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
      -o /etc/yum.repos.d/tailscale.repo
'

# ==============================================================================
# 2. ACTUALIZAR SISTEMA
# ==============================================================================
critical "Actualizar Fedora 45" /usr/bin/dnf upgrade -y

# ==============================================================================
# 3. VERIFICAR KDE PLASMA (YA VIENE EN EL SPIN)
# ==============================================================================
echo -e "${AZUL}3. Verificando KDE Plasma...${NC}"

# La sesión X11 es opcional; Wayland sigue siendo la sesión principal.
optional "Instalar sesión X11 de Plasma como alternativa" \
    dnf_install plasma-workspace-x11

critical "Seleccionar arranque gráfico" /usr/bin/systemctl set-default graphical.target
critical "Habilitar login manager ($DM_SERVICE)" /usr/bin/systemctl enable --force "$DM_SERVICE"

# ==============================================================================
# 4. RETIRAR APLICACIONES SOBRANTES SIN DESMONTAR KDE
# ==============================================================================
# Se retiran solo paquetes instalados y solo si la guarda lo aprueba.
# Los nombres que no existan en el spin se ignoran sin error.
echo -e "${AZUL}4. Retirando bloatware...${NC}"

optional "Retirar Discover y PackageKit" \
    remove_safely \
    discover discover-notifier plasma-discover plasma-discover-notifier \
    plasma-discover-flatpak plasma-discover-packagekit \
    plasma-discover-offline-updates plasma-discover-snap \
    PackageKit PackageKit-command-not-found PackageKit-gtk3-module \
    PackageKit-glib

optional "Retirar aplicaciones KDE no deseadas (juegos, PIM, educativas, red)" \
    remove_safely \
    kmahjongg kmines kpat kfourinline kblocks ksnakeduel \
    kalgebra kanagram kwordquiz parley \
    kontact kmail korganizer akregator kaddressbook konversation \
    kgpg kleopatra ktorrent transmission krfb krdp krdc kget \
    khelpcenter kfind kcharselect

optional "Retirar multimedia y utilidades KDE que no se ocupan" \
    remove_safely \
    elisa juk dragonplayer kamoso kmouth kmag kmousetool \
    kolourpaint skanpage skanlite kdebugsettings

optional "Retirar bienvenida, ayuda, vault, impresión y reportes de errores" \
    remove_safely \
    plasma-welcome plasma-welcome-fedora \
    kinfocenter kdeplasma-addons plasma-vault plasma-thunderbolt \
    plasma-print-manager cups-pk-helper \
    abrt abrt-desktop abrt-cli abrt-gui abrt-addon-ccpp abrt-addon-journal \
    abrt-addon-kerneloops abrt-addon-pstoreoops abrt-addon-vmcore \
    abrt-addon-xorg abrt-plugin-bodhi abrt-dbus abrt-libs abrt-tui \
    yelp

optional "Retirar Fedora Media Writer y restos del instalador live" \
    remove_safely \
    mediawriter anaconda-live anaconda-install-env-deps

# No se elimina Dolphin, NetworkManager, PipeWire, BlueZ, firmware ni componentes
# del sistema. No se ejecuta autoremove para evitar sorpresas.
optional "Limpiar caché de PackageKit/Discover" \
    rm -rf "$USER_HOME/.local/share/discover" "$USER_HOME/.cache/discover" \
           /var/cache/PackageKit

# ------------------------------------------------------------------------------
# 4b. Métodos de entrada e idiomas (teclado latam, región Chile)
# ------------------------------------------------------------------------------
# Con teclado latam, ñ, tildes y teclas muertas funcionan por XKB: no hacen falta
# frameworks de métodos de entrada (ibus/fcitx5), pensados para chino, japonés,
# coreano, etc. Se conservan solo los idiomas es (Chile) y en.
echo -e "${AZUL}4b. Retirando métodos de entrada e idiomas sobrantes...${NC}"

optional "Retirar métodos de entrada (ibus/fcitx5) no necesarios" \
    remove_safely \
    ibus ibus-gtk3 ibus-gtk4 ibus-setup ibus-typing-booster \
    ibus-hangul ibus-libpinyin ibus-anthy ibus-m17n ibus-table \
    ibus-table-chinese ibus-libzhuyin ibus-chewing ibus-cangjie \
    ibus-kkc ibus-libthai ibus-sayura ibus-unikey \
    fcitx5 fcitx5-autostart fcitx5-gtk fcitx5-qt fcitx5-configtool \
    fcitx5-chinese-addons fcitx5-hangul fcitx5-anthy fcitx5-mozc \
    kcm-fcitx5 kcm-fcitx5-qt \
    im-chooser

# Lista dinámica: todos los langpacks-* excepto es y en.
remove_other_langpacks() {
    local pkgs=()
    mapfile -t pkgs < <(rpm -qa --qf '%{NAME}\n' \
        | grep -E '^langpacks-' | grep -Ev -- '-(es|en)$' | sort -u)
    if ((${#pkgs[@]})); then
        remove_safely "${pkgs[@]}"
    else
        echo "No hay langpacks adicionales instalados."
    fi
}
optional "Retirar langpacks de idiomas distintos a es/en" remove_other_langpacks

# glibc-all-langpacks pesa bastante; se reemplaza por los locales es y en
# (es_CL viene dentro de glibc-langpack-es). Solo si está instalado.
if rpm -q glibc-all-langpacks >/dev/null 2>&1; then
    optional "Instalar locales glibc es y en" \
        dnf_install glibc-langpack-es glibc-langpack-en
    if rpm -q glibc-langpack-es glibc-langpack-en >/dev/null 2>&1; then
        optional "Reemplazar glibc-all-langpacks por locales es/en" \
            remove_safely glibc-all-langpacks
    else
        warn "No se instalaron los locales es/en; se conserva glibc-all-langpacks."
    fi
else
    optional "Asegurar locales glibc es y en" \
        dnf_install glibc-langpack-es glibc-langpack-en
fi

# ==============================================================================
# 5. HERRAMIENTAS ESENCIALES
# ==============================================================================
echo -e "${AZUL}5. Instalando herramientas esenciales...${NC}"

critical "Instalar utilidades de consola, archivos y diagnóstico" \
    dnf_install \
    xz bzip2 unrar p7zip wl-clipboard lbzip2 lzma arj lzop cpio \
    git webp-pixbuf-loader unar curl cabextract fontconfig \
    btop nano lm_sensors ripgrep fastfetch \
    kde-connect bluez fuse fuse-libs

optional "Instalar Tailscale" dnf_install tailscale
optional "Habilitar Tailscale (no inicia sesión automáticamente)" \
    /usr/bin/systemctl enable tailscaled

optional "Habilitar Bluetooth" /usr/bin/systemctl enable bluetooth

# Carpetas estándar del usuario.
optional "Crear carpetas estándar del usuario" \
    as_user xdg-user-dirs-update

# ==============================================================================
# 6. FISH SHELL
# ==============================================================================
echo -e "${AZUL}6. Configurando Fish...${NC}"

critical "Instalar Fish" dnf_install fish

FISH_BIN="$(command -v fish || true)"
if [[ -n "$FISH_BIN" ]]; then
    grep -qxF "$FISH_BIN" /etc/shells || echo "$FISH_BIN" >> /etc/shells
    optional "Cambiar shell del usuario a Fish" chsh -s "$FISH_BIN" "$REAL_USER"

    install -d -o "$REAL_USER" -g "$REAL_USER" "$USER_HOME/.config/fish"
    backup_file "$USER_HOME/.config/fish/config.fish"
    cat >"$USER_HOME/.config/fish/config.fish" <<'FISHCONF'
set -g fish_greeting ""
alias update='sudo dnf upgrade -y && flatpak update -y'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

function fish_prompt
    set_color green
    echo -n (whoami)
    set_color normal
    echo -n '@'
    set_color blue
    echo -n (hostname)
    set_color normal
    echo -n ':'
    set_color yellow
    echo -n (prompt_pwd)
    set_color normal
    echo -n ' $ '
end
FISHCONF
    chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/fish/config.fish"
    ok "Fish configurado"
else
    warn "No se encontró el ejecutable Fish después de instalarlo."
fi

# ==============================================================================
# 7. FUENTES E ICONOS
# ==============================================================================
echo -e "${AZUL}7. Instalando fuentes e iconos...${NC}"

optional "Instalar fuentes e iconos" dnf_install \
    google-noto-sans-fonts liberation-fonts fira-code-fonts \
    rsms-inter-fonts papirus-icon-theme adwaita-cursor-theme

# ==============================================================================
# 8. MULTIMEDIA Y DRIVERS INTEL
# ==============================================================================
# Se usa el paquete FFmpeg de RPM Fusion mediante --allowerasing para resolver
# el conflicto normal con ffmpeg-free. No se fuerzan parámetros i915 GuC/HuC.
echo -e "${AZUL}8. Instalando códecs y soporte multimedia Intel...${NC}"

optional "Instalar FFmpeg completo desde RPM Fusion" \
    /usr/bin/dnf install -y ffmpeg --allowerasing

optional "Instalar códecs GStreamer adicionales" \
    dnf_install \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-plugin-libav \
    libfreeaptx libldac fdk-aac

optional "Habilitar repositorio Cisco OpenH264 e instalar códec" bash -c '
    set -e
    dnf config-manager setopt fedora-cisco-openh264.enabled=1
    dnf install -y --skip-unavailable gstreamer1-plugin-openh264 mozilla-openh264
'

# UHD 600: mantener i915/Mesa del kernel y añadir VA-API si está disponible.
# No instalar simultáneamente el driver VA legacy i965 y el moderno iHD.
optional "Instalar driver Intel VA-API moderno y herramientas" \
    dnf_install intel-media-driver libva-utils mesa-va-drivers

# ==============================================================================
# 9. ZRAM
# ==============================================================================
# No reiniciar systemd-zram-setup@zram0.service durante la instalación:
# si /dev/zram0 ya está activo como swap, reiniciarlo puede fallar por estar
# ocupado. La nueva configuración se aplica limpiamente en el próximo arranque.
#
# Para 8 GB: ram / 2 = aproximadamente 4 GB de tamaño máximo de swap comprimido.
# No reserva 4 GB de RAM al arrancar; la memoria física se consume al utilizarlo.
echo -e "${AZUL}9. Configurando ZRAM de forma segura...${NC}"

optional "Instalar zram-generator y sus valores predeterminados" \
    dnf_install zram-generator zram-generator-defaults

ZRAM_CONF="/etc/systemd/zram-generator.conf"
backup_file "$ZRAM_CONF"
install -d -m 0755 /etc/systemd
cat >"$ZRAM_CONF" <<'ZRAMCONF'
[zram0]
zram-size = ram / 2
compression-algorithm = lz4
swap-priority = 100
ZRAMCONF
chmod 0644 "$ZRAM_CONF"
ok "Configuración ZRAM escrita; se aplicará al reiniciar (no se reinicia el dispositivo en caliente)."

# ==============================================================================
# 10. SYSCTL
# ==============================================================================
echo -e "${AZUL}10. Ajustes prudentes de memoria...${NC}"

backup_file /etc/sysctl.d/99-zram-tune.conf
cat >/etc/sysctl.d/99-zram-tune.conf <<'SYSCTL'
vm.swappiness = 100
vm.page-cluster = 0
vm.vfs_cache_pressure = 75
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
fs.inotify.max_user_watches = 524288
SYSCTL
chmod 0644 /etc/sysctl.d/99-zram-tune.conf
optional "Aplicar parámetros sysctl" /usr/sbin/sysctl --system

# ==============================================================================
# 11. FIREWALL, KDE CONNECT Y LOCAL SEND
# ==============================================================================
echo -e "${AZUL}11. Configurando firewall...${NC}"

if rpm -q firewalld >/dev/null 2>&1; then
    optional "Abrir puertos KDE Connect (1714-1764 TCP/UDP) y LocalSend (53317 TCP/UDP)" bash -c '
        set -e
        firewall-cmd --permanent --add-port=1714-1764/tcp
        firewall-cmd --permanent --add-port=1714-1764/udp
        firewall-cmd --permanent --add-port=53317/tcp
        firewall-cmd --permanent --add-port=53317/udp
        firewall-cmd --reload
    '
else
    warn "firewalld no está instalado; no se modificó el firewall."
fi

# Teclado latinoamericano. localectl administra la configuración persistente.
optional "Configurar teclado latinoamericano" \
    /usr/bin/localectl set-x11-keymap latam pc105

optional "Configurar teclado latam en consola (TTY)" \
    /usr/bin/localectl set-keymap latam

# Región Chile: idioma y formatos en es_CL (requiere glibc-langpack-es).
if locale -a 2>/dev/null | grep -qi '^es_CL\.utf-\?8$'; then
    optional "Configurar locale es_CL.UTF-8" \
        /usr/bin/localectl set-locale LANG=es_CL.UTF-8
else
    warn "El locale es_CL.UTF-8 no está disponible; no se cambió el idioma del sistema."
fi

# No se deshabilita NetworkManager-wait-online: puede ser requerido por servicios.
optional "Habilitar TRIM periódico para SSD" \
    /usr/bin/systemctl enable --now fstrim.timer

# ==============================================================================
# 12. OPTIMIZAR KDE SIN DESACTIVAR EL COMPOSITOR
# ==============================================================================
# En Wayland KWin necesita composición. Se desactivan efectos visuales costosos,
# pero NO se fuerza Compositing/Enabled=false.
echo -e "${AZUL}12. Optimizando KDE...${NC}"

optional "Aplicar ajustes ligeros de KWin y Dolphin" \
    as_user bash -c '
        set -e
        command -v kwriteconfig6 >/dev/null 2>&1 || exit 0

        kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
        kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_translucencyEnabled false
        kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_dimscreenEnabled false
        kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_fadedesktopEnabled false
        kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_scaleEnabled false
        kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_squashEnabled false
        kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_zoomEnabled false
        kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_slideEnabled false
        kwriteconfig6 --file kwinrc --group Desktops --key Number 1
        kwriteconfig6 --file dolphinrc --group General --key ShowThumbnails false
    '

# ==============================================================================
# 13. SERVICIOS OPCIONALES
# ==============================================================================
# No se deshabilitan Avahi, switcheroo-control, fwupd ni NetworkManager:
# pueden aportar descubrimiento de red, compatibilidad o actualizaciones firmware.
echo -e "${AZUL}13. Desactivando solo servicios prescindibles...${NC}"

optional "Deshabilitar PackageKit si quedó instalado" bash -c '
    if rpm -q PackageKit >/dev/null 2>&1; then
        systemctl disable --now packagekit.service || true
        systemctl mask packagekit.service || true
    fi
'

optional "Deshabilitar ModemManager si no se utiliza módem móvil" \
    /usr/bin/systemctl disable --now ModemManager.service

# Impresión se deja desactivada si CUPS existe, igual que en el script original.
optional "Deshabilitar CUPS (no se configuró impresión)" \
    /usr/bin/systemctl disable --now cups.service

# Baloo: detener indexación de archivos para ahorrar E/S y memoria.
optional "Desactivar indexador Baloo del usuario" \
    as_user bash -c '
        if command -v balooctl6 >/dev/null 2>&1; then
            balooctl6 suspend || true
            balooctl6 disable || true
        elif command -v balooctl >/dev/null 2>&1; then
            balooctl suspend || true
            balooctl disable || true
        fi
    '

# ==============================================================================
# 14. GAMING Y STEAM
# ==============================================================================
echo -e "${AZUL}14. Instalando Steam y herramientas gaming...${NC}"

optional "Instalar Steam, GameMode, MangoHud y GOverlay" \
    dnf_install steam gamemode gamemode-devel mangohud goverlay fuse fuse-libs

# ==============================================================================
# 15. CARPETAS DEL USUARIO
# ==============================================================================
echo -e "${AZUL}15. Preparando carpetas del usuario...${NC}"

install -d -o "$REAL_USER" -g "$REAL_USER" \
    "$USER_HOME/.config/autostart" \
    "$USER_HOME/.local/bin" \
    "$USER_HOME/.config/environment.d"

# Editor nano con números de línea, sin duplicar la opción.
touch "$USER_HOME/.nanorc"
grep -qxF 'set linenumbers' "$USER_HOME/.nanorc" || \
    echo 'set linenumbers' >>"$USER_HOME/.nanorc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.nanorc"

# ==============================================================================
# 16. APLICACIONES FLATPAK
# ==============================================================================
echo -e "${AZUL}16. Instalando aplicaciones Flatpak...${NC}"

optional "Actualizar metadatos de Flathub" \
    /usr/bin/flatpak update --appstream -y

FLATPAK_APPS=(
    "com.discordapp.Discord"
    "com.vysp3r.ProtonPlus"
    "com.github.tchx84.Flatseal"
    "io.github.flattool.Warehouse"
    "org.telegram.desktop"
    "org.localsend.localsend_app"
    "io.missioncenter.MissionCenter"
    "io.github.kolunmi.Bazaar"
)

for app in "${FLATPAK_APPS[@]}"; do
    optional "Instalar Flatpak $app" \
        /usr/bin/flatpak install --system -y --noninteractive flathub "$app"
done

# ==============================================================================
# 17. SELECCIÓN DE NAVEGADOR
# ==============================================================================
# El KDE Spin puede traer Firefox preinstalado. Si eliges "Omitir" se deja tal cual.
echo
echo "============================================================"
echo " SELECCIÓN DE NAVEGADOR"
echo "============================================================"
echo "1. Firefox RPM (aplica ajustes Fastfox)"
echo "2. Microsoft Edge RPM"
echo "3. Ambos"
echo "4. Omitir"
echo "------------------------------------------------------------"

browser_choice="4"
if [[ -r /dev/tty ]]; then
    read -r -p "Elige una opción [1-4, por defecto 4]: " browser_choice </dev/tty || browser_choice="4"
fi
[[ "$browser_choice" =~ ^[1-4]$ ]] || browser_choice="4"

# ---- Firefox ----
if [[ "$browser_choice" == "1" || "$browser_choice" == "3" ]]; then
    optional "Instalar Firefox RPM" dnf_install firefox

    cat >"$USER_HOME/.config/environment.d/99-firefox-wayland.conf" <<'FIREFOXENV'
MOZ_ENABLE_WAYLAND=1
FIREFOXENV
    chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/environment.d/99-firefox-wayland.conf"

    # Helper para aplicar Fastfox después de que el usuario haya creado su perfil.
    cat >"$USER_HOME/.local/bin/fix-firefox-tweaks.sh" <<'FIREFOXSCRIPT'
#!/usr/bin/env bash
set -euo pipefail
PROFILE_DIR="$(find "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" \
    -maxdepth 1 -type d \( -name '*.default' -o -name '*.default-release' -o -name '*.default-esr' \) \
    2>/dev/null | head -n 1 || true)"

if [[ -z "$PROFILE_DIR" ]]; then
    echo "No se encontró un perfil. Abre Firefox una vez, ciérralo y vuelve a ejecutar este script."
    exit 1
fi

curl -fL --retry 3 \
    https://raw.githubusercontent.com/yokoffing/Betterfox/main/Fastfox.js \
    -o "$PROFILE_DIR/user.js"

cat >>"$PROFILE_DIR/user.js" <<'PREFS'
user_pref("dom.ipc.processCount", 2);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("gfx.webrender.all", true);
PREFS

echo "Tweaks aplicados a: $PROFILE_DIR"
FIREFOXSCRIPT
    chmod 0755 "$USER_HOME/.local/bin/fix-firefox-tweaks.sh"
    chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.local/bin/fix-firefox-tweaks.sh"

    # Si ya existe un perfil, se intenta aplicar; si no, el usuario podrá usar el helper.
    optional "Aplicar ajustes Firefox si ya existe perfil" \
        as_user "$USER_HOME/.local/bin/fix-firefox-tweaks.sh"
fi

# ---- Microsoft Edge ----
if [[ "$browser_choice" == "2" || "$browser_choice" == "3" ]]; then
    optional "Agregar repositorio y clave oficial de Microsoft Edge" bash -c '
        set -e
        curl -fsSL https://packages.microsoft.com/yumrepos/edge/config.repo \
            -o /etc/yum.repos.d/microsoft-edge.repo
        rpm --import https://packages.microsoft.com/keys/microsoft.asc
    '

    optional "Instalar Microsoft Edge estable" dnf_install microsoft-edge-stable

    # No se desactiva el sandbox del navegador ni se fuerza el uso de flags
    # experimentales que pueden causar fallos gráficos en Intel UHD 600.
fi

# ==============================================================================
# 18. LIMPIEZA SEGURA
# ==============================================================================
echo -e "${AZUL}18. Limpieza final...${NC}"

optional "Eliminar runtimes Flatpak que ya no se usan" \
    /usr/bin/flatpak uninstall --unused -y

optional "Limpiar caché DNF" /usr/bin/dnf clean all

optional "Actualizar base de datos de accesos directos" \
    /usr/bin/update-desktop-database

# No se fuerza dracut: no hemos cambiado drivers ni módulos del kernel.
# Tampoco se ejecuta autoremove ni se reinicia automáticamente.

# ==============================================================================
# 19. RESUMEN
# ==============================================================================
{
    echo
    echo "=== RESUMEN POST-INSTALACION ==="
    echo "Fecha: $(date)"
    echo "--- ZRAM ---"
    zramctl 2>&1 || true
    swapon --show 2>&1 || true
    echo "--- VA-API ---"
    vainfo 2>&1 | head -n 35 || true
    echo "--- GPU / i915 ---"
    lspci -nnk 2>&1 | grep -A3 -Ei 'VGA|Display|3D' || true
    echo "--- Kernel ---"
    uname -r
} >>"$LOG_FILE" 2>&1

chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

echo
echo -e "${VERDE}============================================================${NC}"
echo -e "${VERDE} DEBLOAT FINALIZADO${NC}"
echo -e "${VERDE} Fedora 45 KDE Spin${NC}"
echo -e "${VERDE}============================================================${NC}"
echo "Registro: $LOG_FILE"
echo
echo "IMPORTANTE:"
echo " - Reinicia para que ZRAM aplique la nueva configuración."
echo " - No se ha reiniciado ZRAM en caliente para evitar 'device busy'."
echo " - Si elegiste Firefox y aún no existía perfil, abre/cierra Firefox y ejecuta:"
echo "   ~/.local/bin/fix-firefox-tweaks.sh"
echo " - Comprueba ZRAM después del reinicio con: zramctl && swapon --show"
echo " - Para ver qué se eliminó: grep -E 'OMITIDO|Removing|Eliminando' $LOG_FILE"
echo
read -r -p "¿Reiniciar ahora? [s/N]: " reboot_choice </dev/tty || reboot_choice="n"
if [[ "$reboot_choice" =~ ^[sS]$ ]]; then
    /usr/bin/systemctl reboot
else
    echo "No se reinició. Hazlo cuando estés listo."
fi
