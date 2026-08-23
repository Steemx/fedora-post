#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE POST-INSTALACIÓN UNIVERSAL PARA FEDORA EVERYTHING
# Compatible con: GNOME, KDE, XFCE, Cinnamon, Mate, Budgie, etc.
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# ==============================================================================

# Colores para la terminal
VERDE='\033[0;32m'
ANUNCIAR='\033[1;34m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
NC='\033[0m' # Sin color

# Asegurar que el script se ejecute como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}Por favor, ejecuta este script usando sudo: sudo $0${NC}"
    exit 1
fi

# Guardar el usuario real para las configuraciones de carpetas y temas
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$REAL_USER)
LOG_FILE="$USER_HOME/fedora_universal_install_report.log"

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
# DETECCIÓN AUTOMÁTICA DEL ESCRITORIO INSTALADO
# ==============================================================================
detect_desktop_environment() {
    DETECTED_DE="unknown"
    DETECTED_DM="unknown"
    
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
    
    # Detectar display manager
    if rpm -q gdm &>/dev/null; then
        DETECTED_DM="gdm"
    elif rpm -q sddm &>/dev/null; then
        DETECTED_DM="sddm"
    elif rpm -q lightdm &>/dev/null; then
        DETECTED_DM="lightdm"
    elif rpm -q lxdm &>/dev/null; then
        DETECTED_DM="lxdm"
    elif rpm -q ly &>/dev/null; then
        DETECTED_DM="ly"
    fi
    
    # Permitir override por variable de entorno
    if [ -n "$FORCE_DE" ]; then
        DETECTED_DE="$FORCE_DE"
        echo -e "${AMARILLO}⚠ Usando escritorio forzado: $DETECTED_DE${NC}"
    fi
}

detect_desktop_environment

echo -e "${ANUNCIAR}=== INICIANDO CONFIGURACIÓN DE POST-INSTALACIÓN UNIVERSAL ===${NC}"
echo "=== REPORTE DE POST-INSTALACIÓN DE FEDORA (UNIVERSAL) ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Hardware objetivo: Celeron N4020 / 8GB RAM / 256GB SSD" >> "$LOG_FILE"
echo "Entorno detectado: $DETECTED_DE" >> "$LOG_FILE"
echo "Display Manager detectado: $DETECTED_DM" >> "$LOG_FILE"
echo "--------------------------------------------" >> "$LOG_FILE"

echo -e "${VERDE}Entorno de escritorio detectado: ${AMARILLO}${DETECTED_DE^^}${NC}"
echo -e "${VERDE}Display Manager detectado: ${AMARILLO}${DETECTED_DM^^}${NC}"
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
/usr/bin/dnf -y install dnf-plugins-core
/usr/bin/dnf -y install flatpak
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Microsoft Edge
rpm --import https://packages.microsoft.com/keys/microsoft.asc
printf '%s\n' \
'[microsoft-edge]' \
'name=microsoft-edge' \
'baseurl=https://packages.microsoft.com/yumrepos/edge-stable' \
'enabled=1' \
'gpgcheck=1' \
'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' | sudo tee /etc/yum.repos.d/microsoft-edge.repo > /dev/null

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
# 4. INSTALACIÓN ESPECÍFICA POR ESCRITORIO
# ==============================================================================
echo -e "${ANUNCIAR}=== 4. Instalaciones específicas para $DETECTED_DE ===${NC}"

case "$DETECTED_DE" in
    gnome)
        echo -e "${VERDE}→ Configurando GNOME...${NC}"
        /usr/bin/dnf install -y microsoft-edge-stable
        flatpak install -y flathub org.gnome.Extensions || true
        systemctl enable gdm.service
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gnome
        ;;
    kde)
        echo -e "${VERDE}→ Configurando KDE Plasma...${NC}"
        /usr/bin/dnf install -y microsoft-edge-stable
        flatpak install -y flathub org.kde.kconfigeditor || true
        systemctl enable sddm.service
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-kde
        ;;
    xfce)
        echo -e "${VERDE}→ Configurando XFCE...${NC}"
        /usr/bin/dnf install -y microsoft-edge-stable
        systemctl enable lightdm.service
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gtk
        ;;
    cinnamon)
        echo -e "${VERDE}→ Configurando Cinnamon...${NC}"
        /usr/bin/dnf install -y microsoft-edge-stable
        systemctl enable lightdm.service
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gtk
        ;;
    mate)
        echo -e "${VERDE}→ Configurando MATE...${NC}"
        /usr/bin/dnf install -y microsoft-edge-stable
        systemctl enable lightdm.service
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gtk
        ;;
    *)
        echo -e "${AMARILLO}⚠ Entorno no reconocido ($DETECTED_DE). Aplicando configuración genérica.${NC}"
        /usr/bin/dnf install -y microsoft-edge-stable
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber
        ;;
esac

log_status $? "Instalaciones específicas para $DETECTED_DE"

# ==============================================================================
# 4b. ELIMINACIÓN DE TIENDAS Y PACKAGEKIT (OPTIMIZACIÓN)
# ==============================================================================
echo -e "${ANUNCIAR}=== 4b. Eliminando tiendas gráficas y PackageKit ===${NC}"

case "$DETECTED_DE" in
    gnome)
        /usr/bin/dnf remove -y gnome-software gnome-software-rpm-ostree packagekit \
            packagekit-gtk3-module PackageKit-command-not-found yelp \
            gnome-contacts simple-scan gnome-tour rxvt-unicode gnome-terminal 2>/dev/null || true
        rm -rf "$USER_HOME/.local/share/gnome-software"
        rm -rf "$USER_HOME/.cache/gnome-software"
        ;;
    kde)
        /usr/bin/dnf remove -y plasma-discover plasma-discover-notifier packagekit \
            packagekit-qt6 2>/dev/null || true
        rm -rf "$USER_HOME/.local/share/discover"
        ;;
    *)
        # Genérico: intentar remover cualquier tienda
        /usr/bin/dnf remove -y gnome-software plasma-discover packagekit 2>/dev/null || true
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
    fontconfig btop xdg-user-dirs nano

# Crear carpetas del Home
sudo -u "$REAL_USER" xdg-user-dirs-update

# Nano con números de línea
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown $REAL_USER:$REAL_USER "$USER_HOME/.nanorc"
log_status $? "Herramientas de compresión y utilidades"

# ==============================================================================
# 5c. INSTALANDO Y CONFIGURANDO FISH SHELL
# ==============================================================================
echo -e "${ANUNCIAR}=== 5c. Instalando Fish Shell ===${NC}"
/usr/bin/dnf install -y fish
chsh -s /bin/fish "$REAL_USER"

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
# 6. FUENTES Y TEMAS
# ==============================================================================
echo -e "${ANUNCIAR}=== 6. Instalando fuentes del sistema ===${NC}"
/usr/bin/dnf install -y \
    google-noto-sans-fonts google-noto-serif-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme

# Cursor theme según el escritorio
case "$DETECTED_DE" in
    kde)
        /usr/bin/dnf install -y breeze-cursor-theme
        ;;
    *)
        /usr/bin/dnf install -y adwaita-cursor-theme
        ;;
esac
log_status $? "Fuentes del sistema"

# ==============================================================================
# 7. CÓDECS MULTIMEDIA Y DRIVERS DE VIDEO
# ==============================================================================
echo -e "${ANUNCIAR}=== 7. Configurando Códecs y Drivers de Video Intel ===${NC}"
/usr/bin/dnf remove -y ffmpeg-free libavcodec-free libavformat-free libavutil-free libswscale-free libswresample-free libpostproc-free
/usr/bin/dnf install -y ffmpeg ffmpeg-libs libavdevice --allowerasing
/usr/bin/dnf install -y libfreeaptx libldac fdk-aac gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav
/usr/bin/dnf install -y intel-media-driver libva libva-utils
/usr/bin/dnf config-manager setopt fedora-cisco-openh264.enabled=1
/usr/bin/dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
log_status $? "Códecs multimedia y drivers Intel"

# ==============================================================================
# 8. AJUSTES DE RENDIMIENTO (ZRAM Y SYSCTL)
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
# 9. GRÁFICOS INTEL (GuC/HuC)
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

if [ -f /etc/environment ]; then
    sed -i '/XKB_DEFAULT_LAYOUT/d' /etc/environment
    sed -i '/XKB_DEFAULT_MODEL/d' /etc/environment
fi
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
# 12. DRACUT Y COMPROBACIONES
# ==============================================================================
echo -e "${ANUNCIAR}=== 12. Generando Initramfs (Dracut) y Comprobaciones ===${NC}"
echo "=== Comprobaciones de Hardware Post-Instalación ===" >> "$LOG_FILE"
/usr/sbin/dracut --force -v || { echo -e "${ROJO}❌ Error crítico en dracut.${NC}"; log_status 1 "Generación de Dracut"; }

echo -e "\n[Estado de Intel GuC]:" >> "$LOG_FILE"
/usr/bin/dmesg | grep -i guc >> "$LOG_FILE" 2>&1 || echo "No se encontraron registros de GuC" >> "$LOG_FILE"
echo -e "\n[Estado de Intel HuC]:" >> "$LOG_FILE"
/usr/bin/dmesg | grep -i huc >> "$LOG_FILE" 2>&1 || echo "No se encontraron registros de HuC" >> "$LOG_FILE"
echo -e "\n[Estado de zRAMctl]:" >> "$LOG_FILE"
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || echo "No se pudo ejecutar zramctl" >> "$LOG_FILE"

systemctl set-default graphical.target

# ==============================================================================
# 13. OPTIMIZACIONES ESPECÍFICAS POR ESCRITORIO
# ==============================================================================
echo -e "${ANUNCIAR}=== 13. Optimizando $DETECTED_DE para hardware limitado ===${NC}"
echo "=== Optimizaciones específicas de $DETECTED_DE ===" >> "$LOG_FILE"

case "$DETECTED_DE" in
    gnome)
        echo -e "${VERDE}→ Aplicando optimizaciones de GNOME...${NC}"
        # Desactivar animaciones
        sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $REAL_USER)/bus" \
            gsettings set org.gnome.desktop.interface enable-animations false
        
        # Desactivar Tracker
        systemctl --user --machine="${REAL_USER}@.host" mask tracker-extract-3.service 2>/dev/null || true
        systemctl --user --machine="${REAL_USER}@.host" mask tracker-miner-fs-3.service 2>/dev/null || true
        systemctl --user --machine="${REAL_USER}@.host" mask tracker-writeback-3.service 2>/dev/null || true
        
        # Desactivar Evolution
        systemctl --user --machine="${REAL_USER}@.host" mask evolution-addressbook-factory.service 2>/dev/null || true
        systemctl --user --machine="${REAL_USER}@.host" mask evolution-calendar-factory.service 2>/dev/null || true
        systemctl --user --machine="${REAL_USER}@.host" mask evolution-source-registry.service 2>/dev/null || true
        
        # Desactivar colord
        systemctl disable colord.service 2>/dev/null || true
        
        # Tema ligero
        sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $REAL_USER)/bus" \
            gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
        sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $REAL_USER)/bus" \
            gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>/dev/null || true
        ;;
    
    kde)
        echo -e "${VERDE}→ Aplicando optimizaciones de KDE...${NC}"
        # Desactivar Baloo (indexador de KDE, equivalente a Tracker)
        systemctl --user --machine="${REAL_USER}@.host" mask baloo_file_extractor.service 2>/dev/null || true
        systemctl --user --machine="${REAL_USER}@.host" mask baloo_file.service 2>/dev/null || true
        
        # Desactivar Akonadi (si existe)
        systemctl --user --machine="${REAL_USER}@.host" mask akonadi.service 2>/dev/null || true
        
        # Tema Breeze (nativo y ligero en KDE)
        # Las configuraciones de KDE se hacen vía archivos de config
        mkdir -p "$USER_HOME/.config"
        cat << 'EOF' >> "$USER_HOME/.config/kdeglobals"
[WM]
AnimationsEnabled=false

[Effects]
Enabled=false
EOF
        chown $REAL_USER:$REAL_USER "$USER_HOME/.config/kdeglobals"
        ;;
    
    xfce)
        echo -e "${VERDE}→ Aplicando optimizaciones de XFCE...${NC}"
        # XFCE ya es ligero, solo desactivar animaciones
        sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $REAL_USER)/bus" \
            xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
        ;;
    
    *)
        echo -e "${AMARILLO}⚠ No hay optimizaciones específicas para $DETECTED_DE${NC}"
        ;;
esac

log_status $? "Optimizaciones específicas de $DETECTED_DE"

# ==============================================================================
# 14. ALIAS ÚTILES
# ==============================================================================
echo -e "${ANUNCIAR}=== 14. Configurando alias útiles ===${NC}"
if ! grep -q "alias update=" "$USER_HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$USER_HOME/.bashrc"
    echo "# Alias para actualizar sistema y flatpaks" >> "$USER_HOME/.bashrc"
    echo "alias update='sudo dnf update -y && flatpak update -y'" >> "$USER_HOME/.bashrc"
    chown $REAL_USER:$REAL_USER "$USER_HOME/.bashrc"
    echo "✅ Alias 'update' agregado"
else
    echo "ℹ️  Alias 'update' ya existe"
fi
log_status $? "Configuración de alias"

# ----------------------------------------------------------------------
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Proceso finalizado por completo con éxito." >> "$LOG_FILE"
echo "Entorno configurado: $DETECTED_DE" >> "$LOG_FILE"
echo "Display Manager: $DETECTED_DM" >> "$LOG_FILE"
/usr/bin/chown $REAL_USER:$REAL_USER "$LOG_FILE"

# Mensaje final adaptado al escritorio
case "$DETECTED_DE" in
    gnome)
        DM_NAME="GDM"
        DE_NAME="GNOME"
        ;;
    kde)
        DM_NAME="SDDM"
        DE_NAME="KDE Plasma"
        ;;
    xfce|cinnamon|mate)
        DM_NAME="LightDM"
        DE_NAME="${DETECTED_DE^^}"
        ;;
    *)
        DM_NAME="tu Display Manager"
        DE_NAME="${DETECTED_DE^^}"
        ;;
esac

echo -e "${VERDE}==============================================================================${NC}"
echo -e "${VERDE} ¡PROCESO COMPLETADO! Todo se ha configurado de manera definitiva.            ${NC}"
echo -e "${VERDE} Entorno configurado: ${AMARILLO}${DE_NAME}${VERDE}                                   ${NC}"
echo -e "${VERDE} El equipo se reiniciará automáticamente en 30 segundos...                     ${NC}"
echo -e "${VERDE} Al volver, cargará ${AMARILLO}${DM_NAME}${VERDE} para que inicies sesión en ${DE_NAME}.             ${NC}"
echo -e "${VERDE} Revisa el log en: $LOG_FILE ${NC}"
echo -e "${VERDE}==============================================================================${NC}"
sleep 30
reboot
