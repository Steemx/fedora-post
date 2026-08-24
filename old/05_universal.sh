#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE POST-INSTALACIÓN UNIVERSAL PARA FEDORA EVERYTHING
# SOLO OPTIMIZA - NO INSTALA ESCRITORIOS
# Compatible con: GNOME, KDE, XFCE, Cinnamon, Mate, Budgie, LXQt, etc.
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# ==============================================================================

VERDE='\033[0;32m'
ANUNCIAR='\033[1;34m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}Por favor, ejecuta este script usando sudo: sudo $0${NC}"
    exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$REAL_USER)
LOG_FILE="$USER_HOME/fedora_universal_optimize_report.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${VERDE}[OK] $2${NC}"
        echo "✅ SUCESO: $2" >> "$LOG_FILE"
    else
        echo -e "${ROJO}[ERROR] $2${NC}"
        echo "❌ FALLÓ: $2" >> "$LOG_FILE"
    fi
}

# ==============================================================================
# DETECCIÓN DEL ESCRITORIO YA INSTALADO (NO INSTALA NADA)
# ==============================================================================
detect_desktop_environment() {
    DETECTED_DE="unknown"
    ACTIVE_DM="unknown"
    
    # Detectar entorno de escritorio por paquetes instalados
    if rpm -q gnome-shell &>/dev/null; then
        DETECTED_DE="gnome"
    elif rpm -q plasma-desktop &>/dev/null || rpm -q kde-plasma-workspace &>/dev/null; then
        DETECTED_DE="kde"
    elif rpm -q xfce4-session &>/dev/null; then
        DETECTED_DE="xfce"
    elif rpm -q cinnamon &>/dev/null; then
        DETECTED_DE="cinnamon"
    elif rpm -q mate-session-manager &>/dev/null; then
        DETECTED_DE="mate"
    elif rpm -q budgie-desktop &>/dev/null; then
        DETECTED_DE="budgie"
    elif rpm -q lxqt-session &>/dev/null; then
        DETECTED_DE="lxqt"
    elif rpm -q lxde-common &>/dev/null; then
        DETECTED_DE="lxde"
    fi
    
    # Si no se detectó ningún escritorio, salir con error
    if [ "$DETECTED_DE" = "unknown" ]; then
        echo -e "${ROJO}❌ ERROR: No se detectó ningún entorno de escritorio instalado.${NC}"
        echo -e "${ROJO}   Este script solo optimiza escritorios existentes, no los instala.${NC}"
        echo -e "${AMARILLO}   Por favor, instala primero un escritorio con:${NC}"
        echo -e "${AMARILLO}   sudo dnf groupinstall \"gnome-desktop\"${NC}"
        echo -e "${AMARILLO}   sudo dnf groupinstall \"kde-desktop\"${NC}"
        echo -e "${AMARILLO}   sudo dnf install @xfce-desktop-environment${NC}"
        exit 1
    fi
    
    # Detectar display manager activo
    if systemctl is-enabled --quiet gdm.service 2>/dev/null; then
        ACTIVE_DM="gdm"
    elif systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        ACTIVE_DM="sddm"
    elif systemctl is-enabled --quiet lightdm.service 2>/dev/null; then
        ACTIVE_DM="lightdm"
    elif systemctl is-enabled --quiet lxdm.service 2>/dev/null; then
        ACTIVE_DM="lxdm"
    fi
    
    # Si no se detectó DM activo, asignar según el escritorio
    if [ "$ACTIVE_DM" = "unknown" ]; then
        case "$DETECTED_DE" in
            gnome) ACTIVE_DM="gdm" ;;
            kde|lxqt) ACTIVE_DM="sddm" ;;
            xfce|cinnamon|mate|budgie) ACTIVE_DM="lightdm" ;;
            *) ACTIVE_DM="gdm" ;;
        esac
    fi
}

detect_desktop_environment

echo -e "${ANUNCIAR}=== OPTIMIZANDO SISTEMA FEDORA (SIN INSTALAR ESCRITORIOS) ===${NC}"
echo "=== REPORTE DE OPTIMIZACIÓN ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Entorno detectado: $DETECTED_DE" >> "$LOG_FILE"
echo "Display Manager: $ACTIVE_DM" >> "$LOG_FILE"
echo -e "${VERDE}Entorno detectado: ${AMARILLO}${DETECTED_DE^^}${NC}"
echo -e "${VERDE}Display Manager: ${AMARILLO}${ACTIVE_DM^^}${NC}"
echo ""

# ==============================================================================
# 1. OPTIMIZACIÓN DE DNF
# ==============================================================================
echo -e "${ANUNCIAR}=== 1. Optimizando DNF ===${NC}"
cat << 'EOF' > /etc/dnf/dnf.conf
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=False
max_parallel_downloads=10
defaultyes=True
EOF
log_status $? "Optimización de DNF"

# ==============================================================================
# 2. REPOSITORIOS Y FLATPAK
# ==============================================================================
echo -e "${ANUNCIAR}=== 2. Instalando Repositorios RPM Fusion, Flathub y Otros ===${NC}"
/usr/bin/dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
/usr/bin/dnf -y install dnf-plugins-core flatpak
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Microsoft Edge
rpm --import https://packages.microsoft.com/keys/microsoft.asc
printf '%s\n' \
'[microsoft-edge]' \
'name=microsoft-edge' \
'baseurl=https://packages.microsoft.com/yumrepos/edge-stable' \
'enabled=1' \
'gpgcheck=1' \
'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' | tee /etc/yum.repos.d/microsoft-edge.repo > /dev/null

# Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

log_status $? "Repositorios RPM Fusion, Flathub, Edge y Tailscale"

# ==============================================================================
# 3. ACTUALIZACIÓN DEL SISTEMA BASE
# ==============================================================================
echo -e "${ANUNCIAR}=== 3. Actualizando el sistema base ===${NC}"
/usr/bin/dnf -y update
log_status $? "Actualización del sistema base"

# ==============================================================================
# 4. CONFIGURACIÓN DEL DISPLAY MANAGER (SOLO HABILITAR, NO INSTALAR)
# ==============================================================================
echo -e "${ANUNCIAR}=== 4. Configurando Display Manager: ${ACTIVE_DM^^} ===${NC}"

# Solo habilitar el DM que ya está instalado, NO instalar nada nuevo
echo -e "${VERDE}→ Habilitando ${ACTIVE_DM^^}...${NC}"
systemctl enable "${ACTIVE_DM}.service"

# Deshabilitar otros DMs
for dm in gdm sddm lightdm lxdm ly greetd; do
    if [ "$dm" != "$ACTIVE_DM" ]; then
        systemctl disable "${dm}.service" 2>/dev/null || true
    fi
done

# Forzar target gráfico
systemctl set-default graphical.target

# Servicios de usuario según el escritorio
case "$DETECTED_DE" in
    gnome)
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gnome 2>/dev/null || true
        ;;
    kde)
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-kde 2>/dev/null || true
        ;;
    *)
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gtk 2>/dev/null || true
        ;;
esac

log_status $? "Display Manager configurado: ${ACTIVE_DM^^}"

# ==============================================================================
# 4b. ELIMINACIÓN DE TIENDAS (OPTIMIZACIÓN)
# ==============================================================================
echo -e "${ANUNCIAR}=== 4b. Eliminando tiendas gráficas y PackageKit ===${NC}"

case "$DETECTED_DE" in
    gnome)
        /usr/bin/dnf remove -y gnome-software gnome-software-rpm-ostree packagekit \
            packagekit-gtk3-module PackageKit-command-not-found yelp \
            gnome-contacts simple-scan gnome-tour 2>/dev/null || true
        rm -rf "$USER_HOME/.local/share/gnome-software"
        rm -rf "$USER_HOME/.cache/gnome-software"
        ;;
    kde)
        /usr/bin/dnf remove -y plasma-discover plasma-discover-notifier packagekit \
            packagekit-qt6 2>/dev/null || true
        rm -rf "$USER_HOME/.local/share/discover"
        ;;
esac

/usr/bin/dnf autoremove -y
rm -rf /var/cache/PackageKit
log_status $? "Eliminación de tiendas y PackageKit"

# ==============================================================================
# 5. HERRAMIENTAS BÁSICAS Y UTILIDADES
# ==============================================================================
echo -e "${ANUNCIAR}=== 5. Instalando herramientas de compresión y utilidades ===${NC}"
/usr/bin/dnf -y install \
    xz bzip2 unrar p7zip wl-clipboard xclip lbzip2 lzma arj lzop \
    cpio git webp-pixbuf-loader unar file-roller curl cabextract \
    fontconfig btop xdg-user-dirs nano gvfs gvfs-mtp gvfs-archive

sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown $REAL_USER:$REAL_USER "$USER_HOME/.nanorc"
log_status $? "Herramientas de compresión y utilidades"

# ==============================================================================
# 5c. FISH SHELL
# ==============================================================================
echo -e "${ANUNCIAR}=== 5c. Instalando Fish Shell ===${NC}"
/usr/bin/dnf install -y fish
chsh -s /bin/fish "$REAL_USER"

sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/fish"
cat << 'EOF' > "$USER_HOME/.config/fish/config.fish"
set -g fish_greeting ""
alias update='sudo dnf update -y && flatpak update -y'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
function fish_prompt
    set_color green; echo -n (whoami)
    set_color normal; echo -n '@'
    set_color blue; echo -n (hostname)
    set_color normal; echo -n ':'
    set_color yellow; echo -n (prompt_pwd)
    set_color normal; echo -n ' $ '
end
EOF
chown -R $REAL_USER:$REAL_USER "$USER_HOME/.config/fish"
log_status $? "Fish Shell instalado y configurado"

# ==============================================================================
# 6. FUENTES Y TEMAS
# ==============================================================================
echo -e "${ANUNCIAR}=== 6. Instalando fuentes del sistema ===${NC}"
/usr/bin/dnf install -y \
    google-noto-sans-fonts google-noto-serif-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme

case "$DETECTED_DE" in
    kde|lxqt)
        /usr/bin/dnf install -y breeze-cursor-theme
        ;;
    *)
        /usr/bin/dnf install -y adwaita-cursor-theme
        ;;
esac
log_status $? "Fuentes del sistema"

# ==============================================================================
# 7. CÓDECS MULTIMEDIA Y DRIVERS DE VIDEO (VERSIÓN SEGURA)
# ==============================================================================
echo -e "${ANUNCIAR}=== 7. Configurando Códecs y Drivers de Video Intel ===${NC}"

# MÉTODO SEGURO: Usar swap en lugar de remove + install
# Esto reemplaza los códecs libres por los completos sin romper dependencias
/usr/bin/dnf swap -y ffmpeg-free ffmpeg --allowerasing
/usr/bin/dnf swap -y libavcodec-free libavcodec --allowerasing 2>/dev/null || true
/usr/bin/dnf swap -y libavformat-free libavformat --allowerasing 2>/dev/null || true

# Instalar códecs adicionales de forma segura
/usr/bin/dnf install -y ffmpeg-libs libavdevice --allowerasing
/usr/bin/dnf install -y libfreeaptx libldac fdk-aac
/usr/bin/dnf install -y gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav

# Drivers de video Intel (esto NO rompe el entorno gráfico)
/usr/bin/dnf install -y intel-media-driver libva libva-utils
/usr/bin/dnf config-manager setopt fedora-cisco-openh264.enabled=1
/usr/bin/dnf install -y gstreamer1-plugin-openh264 mozilla-openh264

log_status $? "Códecs multimedia y drivers Intel"
# ==============================================================================
# 8. ZRAM Y SYSCTL
# ==============================================================================
echo -e "${ANUNCIAR}=== 8. Ajustes de Rendimiento (ZRAM y sysctl) ===${NC}"
cat << 'EOF' > /etc/sysctl.d/99-zram-tune.conf
vm.swappiness = 180
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
# 9. GRÁFICOS INTEL
# ==============================================================================
echo -e "${ANUNCIAR}=== 9. Habilitando GuC/HuC para Gráficos Intel ===${NC}"
cat << 'EOF' > /etc/modprobe.d/i915.conf
options i915 enable_guc=2
options i915 enable_fbc=1
options i915 modeset=1
EOF
log_status $? "Configuración Intel GuC/HuC"

# ==============================================================================
# 10. FIREWALL, TECLADO Y ENERGÍA
# ==============================================================================
echo -e "${ANUNCIAR}=== 10. Firewall, Teclado y Energía ===${NC}"
if /usr/bin/rpm -q firewalld &>/dev/null; then
    firewall-cmd --permanent --add-service=kdeconnect
    firewall-cmd --reload
fi

localectl set-x11-keymap latam pc105
sed -i '/XKB_DEFAULT_LAYOUT/d; /XKB_DEFAULT_MODEL/d' /etc/environment 2>/dev/null
cat << 'EOF' >> /etc/environment
XKB_DEFAULT_LAYOUT=latam
XKB_DEFAULT_MODEL=pc105
EOF

/usr/bin/systemctl disable NetworkManager-wait-online.service
/usr/bin/systemctl enable fstrim.timer
/usr/bin/dnf -y swap tuned-ppd power-profiles-daemon 2>/dev/null || true
systemctl enable --now power-profiles-daemon
log_status $? "Firewall, Teclado y Energía"

# ==============================================================================
# 11. LIMPIEZA
# ==============================================================================
echo -e "${ANUNCIAR}=== 11. Limpiando archivos temporales y caché ===${NC}"
/usr/bin/dnf clean all
/usr/bin/flatpak uninstall --unused -y
log_status $? "Limpieza del sistema"

# ==============================================================================
# 12. DRACUT
# ==============================================================================
echo -e "${ANUNCIAR}=== 12. Generando Initramfs (Dracut) ===${NC}"
/usr/sbin/dracut --force -v
log_status $? "Dracut"

# ==============================================================================
# 13. OPTIMIZACIONES ESPECÍFICAS POR ESCRITORIO
# ==============================================================================
echo -e "${ANUNCIAR}=== 13. Optimizando $DETECTED_DE para hardware limitado ===${NC}"
USER_UID=$(id -u "$REAL_USER")
DBUS_ADDR="unix:path=/run/user/${USER_UID}/bus"

case "$DETECTED_DE" in
    gnome)
        sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
        systemctl --user --machine="${REAL_USER}@.host" mask tracker-extract-3.service tracker-miner-fs-3.service tracker-writeback-3.service 2>/dev/null || true
        systemctl --user --machine="${REAL_USER}@.host" mask evolution-addressbook-factory.service evolution-calendar-factory.service evolution-source-registry.service 2>/dev/null || true
        systemctl disable colord.service 2>/dev/null || true
        ;;
    kde)
        systemctl --user --machine="${REAL_USER}@.host" mask baloo_file_extractor.service baloo_file.service akonadi.service 2>/dev/null || true
        ;;
esac
log_status $? "Optimizaciones de $DETECTED_DE"

# ==============================================================================
# 14. ALIAS ÚTILES
# ==============================================================================
echo -e "${ANUNCIAR}=== 14. Configurando alias útiles ===${NC}"
if ! grep -q "alias update=" "$USER_HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$USER_HOME/.bashrc"
    echo "# Alias para actualizar sistema y flatpaks" >> "$USER_HOME/.bashrc"
    echo "alias update='sudo dnf update -y && flatpak update -y'" >> "$USER_HOME/.bashrc"
    chown $REAL_USER:$REAL_USER "$USER_HOME/.bashrc"
fi
log_status $? "Configuración de alias"

# ----------------------------------------------------------------------
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Proceso finalizado con éxito." >> "$LOG_FILE"
/usr/bin/chown $REAL_USER:$REAL_USER "$LOG_FILE"

case "$DETECTED_DE" in
    gnome) DM_NAME="GDM"; DE_NAME="GNOME" ;;
    kde) DM_NAME="SDDM"; DE_NAME="KDE Plasma" ;;
    xfce|cinnamon|mate|budgie) DM_NAME="LightDM"; DE_NAME="${DETECTED_DE^^}" ;;
    lxqt) DM_NAME="SDDM"; DE_NAME="LXQt" ;;
    *) DM_NAME="${ACTIVE_DM^^}"; DE_NAME="${DETECTED_DE^^}" ;;
esac

echo -e "${VERDE}==============================================================================${NC}"
echo -e "${VERDE} ¡OPTIMIZACIÓN COMPLETADA!                                                   ${NC}"
echo -e "${VERDE} Entorno optimizado: ${AMARILLO}${DE_NAME}${VERDE}                                    ${NC}"
echo -e "${VERDE} Reiniciando en 30 segundos...                                               ${NC}"
echo -e "${VERDE} Arrancará en ${AMARILLO}${DM_NAME}${VERDE} → ${DE_NAME}                              ${NC}"
echo -e "${VERDE} Log: $LOG_FILE                                                              ${NC}"
echo -e "${VERDE}==============================================================================${NC}"
sleep 30
reboot
