#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE POST-INSTALACIÓN PARA FEDORA EVERYTHING 44 (GNOME MINIMAL)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# ==============================================================================

# Colores para la terminal
VERDE='\033[0;32m'
ANUNCIAR='\033[1;34m'
ROJO='\033[0;31m'
NC='\033[0m' # Sin color

# Asegurar que el script se ejecute como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}Por favor, ejecuta este script usando sudo: sudo $0${NC}"
    exit 1
fi

# Guardar el usuario real para las configuraciones
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$REAL_USER)
USER_UID=$(id -u "$REAL_USER")
LOG_FILE="$USER_HOME/fedora_gnome_install_report.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${VERDE}[OK] $2${NC}"
        echo "✅ SUCESO: $2" >> "$LOG_FILE"
    else
        echo -e "${ROJO}[ERROR] $2${NC}"
        echo "❌ FALLÓ: $2" >> "$LOG_FILE"
    fi
}

echo -e "${ANUNCIAR}=== INICIANDO CONFIGURACIÓN DE POST-INSTALACIÓN (GNOME MINIMAL) ===${NC}"
echo "=== REPORTE DE POST-INSTALACIÓN DE FEDORA 44 (GNOME) ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Hardware objetivo: Celeron N4020 / 8GB RAM / 256GB SSD" >> "$LOG_FILE"
echo "--------------------------------------------" >> "$LOG_FILE"

# ==============================================================================
# 1. OPTIMIZACIÓN DE DNF
# ==============================================================================
echo -e "${ANUNCIAR}=== 1. Optimizando DNF ===${NC}"
cat << 'EOF' > /etc/dnf/dnf.conf
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=True
max_parallel_downloads=10
defaultyes=True
EOF
log_status $? "Optimización de DNF"

# ==============================================================================
# 2. REPOSITORIOS Y FLATPAK
# ==============================================================================
echo -e "${ANUNCIAR}=== 2. Instalando Repositorios RPM Fusion, Flathub y Otros ===${NC}"

# RPM Fusion
/usr/bin/dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

/usr/bin/dnf -y install dnf-plugins-core flatpak

# Flathub
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Tailscale (repo oficial en lugar de curl | sh)
cat << 'EOF' > /etc/yum.repos.d/tailscale.repo
[tailscale-stable]
name=Tailscale stable
baseurl=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
enabled=1
repo_gpgcheck=1
gpgcheck=0
gpgkey=https://pkgs.tailscale.com/stable/fedora/repo.gpg
EOF

log_status $? "Repositorios RPM Fusion, Flathub, Edge y Tailscale"

# ==============================================================================
# 3. ACTUALIZACIÓN DEL SISTEMA BASE
# ==============================================================================
echo -e "${ANUNCIAR}=== 3. Actualizando el sistema base ===${NC}"
/usr/bin/dnf -y update
log_status $? "Actualización del sistema base"

# ==============================================================================
# 4. INSTALACIÓN DE GNOME MINIMAL (Sin bloatware)
# ==============================================================================
echo -e "${ANUNCIAR}=== 4. Instalando GNOME (Versión Minimalista) ===${NC}"

/usr/bin/dnf install -y \
    gnome-shell gnome-session gnome-control-center gnome-settings-daemon \
    gdm ptyxis nautilus gnome-text-editor gnome-calculator \
    gnome-screenshot gnome-system-monitor gnome-logs \
    gnome-tweaks gnome-keyring \
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
    mutter pipewire pipewire-pulse wireplumber \
    gvfs gvfs-mtp gvfs-archive \
    xdg-user-dirs xdg-user-dirs-gtk

# Instalar extensiones de GNOME vía Flatpak como usuario real
sudo -u "$REAL_USER" flatpak install -y flathub org.gnome.Extensions
sudo -u "$REAL_USER" flatpak install -y flathub com.microsoft.Edge

# Habilitar GDM
systemctl enable --now gdm.service
systemctl set-default graphical.target

log_status $? "GNOME Minimal"

# ==============================================================================
# 5. ELIMINACIÓN DE GNOME-SOFTWARE Y PACKAGEKIT
# ==============================================================================
echo -e "${ANUNCIAR}=== 5. Eliminando gnome-software y PackageKit ===${NC}"

/usr/bin/dnf remove -y \
    gnome-software gnome-software-rpm-ostree \
    packagekit packagekit-gtk3-module PackageKit-command-not-found \
    yelp gnome-contacts simple-scan gnome-tour rxvt-unicode

# Limpiar dependencias huérfanas
/usr/bin/dnf autoremove -y

# Limpiar caché residual
rm -rf "$USER_HOME/.local/share/gnome-software"
rm -rf "$USER_HOME/.cache/gnome-software"
rm -rf /var/cache/PackageKit

log_status $? "Eliminación de gnome-software y PackageKit"

# ==============================================================================
# 6. HERRAMIENTAS BÁSICAS Y UTILIDADES
# ==============================================================================
echo -e "${ANUNCIAR}=== 6. Instalando herramientas de compresión y utilidades ===${NC}"

/usr/bin/dnf -y install \
    xz bzip2 unrar p7zip wl-clipboard xclip lbzip2 lzma arj lzop \
    cpio git webp-pixbuf-loader unar file-roller curl cabextract \
    fontconfig btop nano

# Crear carpetas del Home
sudo -u "$REAL_USER" xdg-user-dirs-update

# Nano con números de línea
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown $REAL_USER:$REAL_USER "$USER_HOME/.nanorc"

log_status $? "Herramientas de compresión y utilidades"

# ==============================================================================
# 7. INSTALANDO Y CONFIGURANDO FISH SHELL
# ==============================================================================
echo -e "${ANUNCIAR}=== 7. Instalando Fish Shell ===${NC}"

/usr/bin/dnf install -y fish

# Asegurar que fish esté en shells válidas
if ! grep -q "/bin/fish" /etc/shells; then
    echo "/bin/fish" >> /etc/shells
fi

# Cambiar la shell por defecto del usuario a fish
chsh -s /bin/fish "$REAL_USER"

# Crear configuración básica de fish
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/fish"
cat << 'EOF' > "$USER_HOME/.config/fish/config.fish"
# Fish shell configuration
set -g fish_greeting ""

# Alias útiles
alias update='sudo dnf update -y && flatpak update -y'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Prompt personalizado (simple)
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
EOF

chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config/fish"

log_status $? "Fish Shell instalado y configurado"

# ==============================================================================
# 8. FUENTES Y TEMAS
# ==============================================================================
echo -e "${ANUNCIAR}=== 8. Instalando fuentes del sistema ===${NC}"

/usr/bin/dnf install -y \
    google-noto-sans-fonts google-noto-serif-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme adwaita-cursor-theme

log_status $? "Fuentes del sistema"

# ==============================================================================
# 9. CÓDECS MULTIMEDIA Y DRIVERS DE VIDEO
# ==============================================================================
echo -e "${ANUNCIAR}=== 9. Configurando Códecs y Drivers de Video Intel ===${NC}"

# Eliminar códecs libres limitados
/usr/bin/dnf remove -y \
    ffmpeg-free libavcodec-free libavformat-free libavutil-free \
    libswscale-free libswresample-free libpostproc-free

# Instalar códecs completos
/usr/bin/dnf install -y ffmpeg ffmpeg-libs libavdevice --allowerasing
/usr/bin/dnf install -y \
    libfreeaptx libldac fdk-aac \
    gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav

# Drivers de video Intel (Intel UHD 600 del N4020)
/usr/bin/dnf install -y intel-media-driver libva libva-utils

# OpenH264
/usr/bin/dnf config-manager setopt fedora-cisco-openh264.enabled=1
/usr/bin/dnf install -y gstreamer1-plugin-openh264 mozilla-openh264

log_status $? "Códecs multimedia y drivers Intel"

# ==============================================================================
# 10. AJUSTES DE RENDIMIENTO (ZRAM Y SYSCTL)
# ==============================================================================
echo -e "${ANUNCIAR}=== 10. Ajustes de Rendimiento (ZRAM y sysctl) ===${NC}"

cat << 'EOF' > /etc/sysctl.d/99-zram-tune.conf
vm.swappiness = 100
vm.page-cluster = 0
vm.vfs_cache_pressure = 50
vm.watermark_scale_factor = 125
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.watermark_boost_factor = 0
fs.inotify.max_user_watches = 524288
EOF

cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = lz4
swap-priority = 100
fs-type = swap
EOF

/usr/bin/systemctl daemon-reload
/usr/bin/systemctl restart systemd-zram-setup@zram0.service

log_status $? "Ajustes de rendimiento (ZRAM y sysctl)"

# ==============================================================================
# 11. GRÁFICOS INTEL (GuC/HuC)
# ==============================================================================
echo -e "${ANUNCIAR}=== 11. Habilitando GuC/HuC para Gráficos Intel ===${NC}"

cat << 'EOF' > /etc/modprobe.d/i915.conf
options i915 enable_guc=2
options i915 enable_fbc=1
options i915 modeset=1
EOF

log_status $? "Configuración Intel GuC/HuC"

# ==============================================================================
# 12. FIREWALL, TECLADO Y ENERGÍA
# ==============================================================================
echo -e "${ANUNCIAR}=== 12. Firewall, Teclado y Energía ===${NC}"

# GSConnect en el firewall
if /usr/bin/rpm -q firewalld &>/dev/null; then
    firewall-cmd --permanent --add-service=kdeconnect
    firewall-cmd --reload
fi

# Teclado latinoamericano
localectl set-x11-keymap latam pc105

# Configurar en /etc/environment para Wayland
if [ -f /etc/environment ]; then
    sed -i '/XKB_DEFAULT_LAYOUT/d' /etc/environment
    sed -i '/XKB_DEFAULT_MODEL/d' /etc/environment
fi

cat << 'EOF' >> /etc/environment
XKB_DEFAULT_LAYOUT=latam
XKB_DEFAULT_MODEL=pc105
EOF

# Optimizaciones de arranque y SSD
/usr/bin/systemctl disable NetworkManager-wait-online.service
/usr/bin/systemctl enable fstrim.timer

log_status $? "Firewall, Teclado y Energía"

# ==============================================================================
# 13. OPTIMIZACIÓN DE GNOME
# ==============================================================================
echo -e "${ANUNCIAR}=== 13. Optimizando GNOME para hardware limitado ===${NC}"

# Configurar gsettings como usuario real con sesión D-Bus temporal
sudo -u "$REAL_USER" dbus-run-session bash -c '
    gsettings set org.gnome.desktop.interface enable-animations false
    gsettings set org.gnome.mutter attach-modal-dialogs false
    gsettings set org.gnome.desktop.interface text-scaling-factor 1.0
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita"
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
'

# Enmascarar servicios de Tracker/Localsearch como usuario real
sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$USER_UID" systemctl --user mask \
    tracker-extract-3.service \
    tracker-miner-fs-3.service \
    tracker-writeback-3.service \
    evolution-addressbook-factory.service \
    evolution-calendar-factory.service \
    evolution-source-registry.service

# Resetear índice de búsqueda (compatible con Fedora 44)
sudo -u "$REAL_USER" localsearch reset -s -r 2>/dev/null || \
sudo -u "$REAL_USER" tracker3 reset -s -r 2>/dev/null

# Deshabilitar servicios del sistema innecesarios
systemctl disable colord.service 2>/dev/null
systemctl disable packagekit.service 2>/dev/null

# Power profiles daemon
/usr/bin/dnf -y swap tuned-ppd power-profiles-daemon
systemctl enable --now power-profiles-daemon

log_status $? "Optimización de GNOME"

# ==============================================================================
# 14. LIMPIEZA Y COMPROBACIONES FINALES
# ==============================================================================
echo -e "${ANUNCIAR}=== 14. Limpiando y generando Initramfs ===${NC}"

/usr/bin/dnf clean all
/usr/bin/flatpak uninstall --unused -y

# Generar initramfs
echo "=== Comprobaciones de Hardware Post-Instalación ===" >> "$LOG_FILE"
/usr/sbin/dracut --force -v || { 
    echo -e "${ROJO}❌ Error crítico en dracut.${NC}"
    log_status 1 "Generación de Dracut"
}

echo -e "\n[Estado de Intel GuC]:" >> "$LOG_FILE"
/usr/bin/dmesg | grep -i guc >> "$LOG_FILE" 2>&1 || echo "No se encontraron registros de GuC" >> "$LOG_FILE"

echo -e "\n[Estado de Intel HuC]:" >> "$LOG_FILE"
/usr/bin/dmesg | grep -i huc >> "$LOG_FILE" 2>&1 || echo "No se encontraron registros de HuC" >> "$LOG_FILE"

echo -e "\n[Estado de zRAMctl]:" >> "$LOG_FILE"
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || echo "No se pudo ejecutar zramctl" >> "$LOG_FILE"

log_status $? "Limpieza y comprobaciones finales"

# ----------------------------------------------------------------------
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Proceso finalizado por completo con éxito." >> "$LOG_FILE"
/usr/bin/chown $REAL_USER:$REAL_USER "$LOG_FILE"

echo -e "${VERDE}==============================================================================${NC}"
echo -e "${VERDE} ¡PROCESO COMPLETADO! Todo se ha configurado de manera definitiva.            ${NC}"
echo -e "${VERDE} Revisa el log en: $LOG_FILE ${NC}"
echo -e "${VERDE}==============================================================================${NC}"
echo ""
read -p "Presiona ENTER para reiniciar el sistema ahora, o Ctrl+C para cancelar..."
reboot
