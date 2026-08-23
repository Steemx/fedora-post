#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE POST-INSTALACIÓN UNIVERSAL PARA FEDORA EVERYTHING (VERSIÓN ROBUSTA)
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
# DETECCIÓN ROBUSTA DEL ESCRITORIO Y DISPLAY MANAGER
# ==============================================================================
detect_desktop_environment() {
    DETECTED_DE="unknown"
    ACTIVE_DM="unknown"
    
    # Detectar entorno de escritorio
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
    fi
    
    # Override manual
    if [ -n "$FORCE_DE" ]; then
        DETECTED_DE="$FORCE_DE"
        echo -e "${AMARILLO}⚠ Usando escritorio forzado: $DETECTED_DE${NC}"
    fi
    
    # Detectar DM activo
    if systemctl is-enabled --quiet gdm.service 2>/dev/null; then
        ACTIVE_DM="gdm"
    elif systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        ACTIVE_DM="sddm"
    elif systemctl is-enabled --quiet lightdm.service 2>/dev/null; then
        ACTIVE_DM="lightdm"
    elif systemctl is-enabled --quiet lxdm.service 2>/dev/null; then
        ACTIVE_DM="lxdm"
    fi
    
    # Si no se detectó DM, asignar según el escritorio
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

echo -e "${ANUNCIAR}=== INICIANDO CONFIGURACIÓN UNIVERSAL ===${NC}"
echo "=== REPORTE DE POST-INSTALACIÓN ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Entorno: $DETECTED_DE | DM: $ACTIVE_DM" >> "$LOG_FILE"
echo -e "${VERDE}Entorno: ${AMARILLO}${DETECTED_DE^^}${NC} | ${VERDE}DM: ${AMARILLO}${ACTIVE_DM^^}${NC}"

# ==============================================================================
# 1-3. DNF, REPOS Y ACTUALIZACIÓN
# ==============================================================================
echo -e "${ANUNCIAR}=== 1-3. DNF, Repositorios y Actualización ===${NC}"
cat << 'EOF' > /etc/dnf/dnf.conf
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=False
max_parallel_downloads=10
defaultyes=True
EOF

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

/usr/bin/dnf -y update
log_status $? "DNF, repos y actualización"

# ==============================================================================
# 4. INSTALACIÓN Y CONFIGURACIÓN DEL DISPLAY MANAGER (CRÍTICO)
# ==============================================================================
echo -e "${ANUNCIAR}=== 4. Configurando Display Manager: ${ACTIVE_DM^^} ===${NC}"

# Instalar el DM correcto según el escritorio
case "$DETECTED_DE" in
    gnome)
        /usr/bin/dnf install -y gdm
        /usr/bin/dnf install -y microsoft-edge-stable
        flatpak install -y flathub org.gnome.Extensions || true
        ;;
    kde)
        /usr/bin/dnf install -y sddm sddm-breeze
        /usr/bin/dnf install -y microsoft-edge-stable
        ;;
    xfce|cinnamon|mate|budgie)
        /usr/bin/dnf install -y lightdm lightdm-gtk
        /usr/bin/dnf install -y microsoft-edge-stable
        ;;
    lxqt)
        /usr/bin/dnf install -y sddm
        /usr/bin/dnf install -y microsoft-edge-stable
        ;;
    *)
        # Fallback: instalar GDM
        /usr/bin/dnf install -y gdm
        ACTIVE_DM="gdm"
        /usr/bin/dnf install -y microsoft-edge-stable
        ;;
esac

# VERIFICACIÓN CRÍTICA: Asegurar que el DM esté habilitado
echo -e "${VERDE}→ Habilitando ${ACTIVE_DM^^}...${NC}"
systemctl enable "${ACTIVE_DM}.service"

# Verificar que realmente se habilitó
if ! systemctl is-enabled --quiet "${ACTIVE_DM}.service"; then
    echo -e "${ROJO}❌ ERROR: No se pudo habilitar ${ACTIVE_DM}.service${NC}"
    echo "Intentando forzar..."
    systemctl --force enable "${ACTIVE_DM}.service"
fi

# DESHABILITAR TODOS LOS DEMÁS DMs
echo -e "${VERDE}→ Deshabilitando otros display managers...${NC}"
for dm in gdm sddm lightdm lxdm ly greetd; do
    if [ "$dm" != "$ACTIVE_DM" ]; then
        systemctl disable "${dm}.service" 2>/dev/null || true
        systemctl mask "${dm}.service" 2>/dev/null || true
    fi
done

# FORZAR TARGET GRÁFICO
echo -e "${VERDE}→ Forzando target gráfico...${NC}"
systemctl set-default graphical.target

# Verificar
CURRENT_TARGET=$(systemctl get-default)
if [ "$CURRENT_TARGET" != "graphical.target" ]; then
    echo -e "${ROJO}❌ ERROR: El target no se cambió a graphical.target${NC}"
    echo "Target actual: $CURRENT_TARGET"
else
    echo -e "${VERDE}✅ Target configurado: graphical.target${NC}"
fi

# Servicios de usuario
case "$DETECTED_DE" in
    gnome)
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gnome
        ;;
    kde)
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-kde
        ;;
    *)
        systemctl --user --machine="${REAL_USER}@.host" enable pipewire pipewire-pulse wireplumber xdg-desktop-portal-gtk
        ;;
esac

log_status $? "Display Manager configurado: ${ACTIVE_DM^^}"

# ==============================================================================
# 4b. ELIMINACIÓN DE TIENDAS
# ==============================================================================
echo -e "${ANUNCIAR}=== 4b. Eliminando tiendas gráficas ===${NC}"
case "$DETECTED_DE" in
    gnome)
        /usr/bin/dnf remove -y gnome-software packagekit yelp gnome-contacts simple-scan gnome-tour 2>/dev/null || true
        ;;
    kde)
        /usr/bin/dnf remove -y plasma-discover packagekit 2>/dev/null || true
        ;;
esac
/usr/bin/dnf autoremove -y
log_status $? "Eliminación de tiendas"

# ==============================================================================
# 5. HERRAMIENTAS BÁSICAS
# ==============================================================================
echo -e "${ANUNCIAR}=== 5. Herramientas básicas ===${NC}"
/usr/bin/dnf -y install \
    xz bzip2 unrar p7zip wl-clipboard xclip lbzip2 lzma arj lzop \
    cpio git webp-pixbuf-loader unar file-roller curl cabextract \
    fontconfig btop xdg-user-dirs nano gvfs gvfs-mtp gvfs-archive fish

sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown $REAL_USER:$REAL_USER "$USER_HOME/.nanorc"

# Fish shell
chsh -s /bin/fish "$REAL_USER"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/fish"
cat << 'EOF' > "$USER_HOME/.config/fish/config.fish"
set -g fish_greeting ""
alias update='sudo dnf update -y && flatpak update -y'
alias ll='ls -lah'
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
log_status $? "Herramientas básicas y Fish"

# ==============================================================================
# 6-7. FUENTES Y CÓDECS
# ==============================================================================
echo -e "${ANUNCIAR}=== 6-7. Fuentes y Códecs ===${NC}"
/usr/bin/dnf install -y \
    google-noto-sans-fonts google-noto-serif-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme

case "$DETECTED_DE" in
    kde|lxqt) /usr/bin/dnf install -y breeze-cursor-theme ;;
    *) /usr/bin/dnf install -y adwaita-cursor-theme ;;
esac

/usr/bin/dnf remove -y ffmpeg-free libavcodec-free libavformat-free libavutil-free libswscale-free libswresample-free libpostproc-free
/usr/bin/dnf install -y ffmpeg ffmpeg-libs libavdevice --allowerasing
/usr/bin/dnf install -y libfreeaptx libldac fdk-aac gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav
/usr/bin/dnf install -y intel-media-driver libva libva-utils
/usr/bin/dnf config-manager setopt fedora-cisco-openh264.enabled=1
/usr/bin/dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
log_status $? "Fuentes y códecs"

# ==============================================================================
# 8-9. ZRAM Y GRÁFICOS INTEL
# ==============================================================================
echo -e "${ANUNCIAR}=== 8-9. ZRAM y Gráficos Intel ===${NC}"
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

cat << 'EOF' > /etc/modprobe.d/i915.conf
options i915 enable_guc=2
options i915 enable_fbc=1
options i915 modeset=1
EOF

/usr/bin/systemctl daemon-reload
/usr/bin/systemctl restart systemd-zram-setup@zram0.service
log_status $? "ZRAM y gráficos Intel"

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
log_status $? "Firewall, teclado y energía"

# ==============================================================================
# 11-12. LIMPIEZA Y DRACUT
# ==============================================================================
echo -e "${ANUNCIAR}=== 11-12. Limpieza y Dracut ===${NC}"
/usr/bin/dnf clean all
/usr/bin/flatpak uninstall --unused -y
/usr/sbin/dracut --force -v
log_status $? "Limpieza y Dracut"

# ==============================================================================
# 13. OPTIMIZACIONES POR ESCRITORIO
# ==============================================================================
echo -e "${ANUNCIAR}=== 13. Optimizando $DETECTED_DE ===${NC}"
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
# VERIFICACIÓN FINAL ANTES DE REINICIAR
# ==============================================================================
echo -e "${ANUNCIAR}=== VERIFICACIÓN FINAL ===${NC}"
echo ""
echo -e "${VERDE}Resumen de configuración:${NC}"
echo "  Target: $(systemctl get-default)"
echo "  Display Manager: ${ACTIVE_DM^^}"
echo "  Estado DM: $(systemctl is-enabled ${ACTIVE_DM}.service 2>/dev/null)"
echo "  Entorno: ${DETECTED_DE^^}"
echo ""

# Verificación crítica
if [ "$(systemctl get-default)" != "graphical.target" ]; then
    echo -e "${ROJO}❌ ADVERTENCIA: El target NO es graphical.target${NC}"
    echo -e "${ROJO}   Esto puede causar que el sistema arranque en TTY${NC}"
fi

if ! systemctl is-enabled --quiet "${ACTIVE_DM}.service"; then
    echo -e "${ROJO}❌ ADVERTENCIA: ${ACTIVE_DM^^} NO está habilitado${NC}"
    echo -e "${ROJO}   Esto puede causar que el sistema arranque en TTY${NC}"
fi

echo -e "${VERDE}==============================================================================${NC}"
echo -e "${VERDE} ¡PROCESO COMPLETADO!                                                        ${NC}"
echo -e "${VERDE} Reiniciando en 30 segundos...                                               ${NC}"
echo -e "${VERDE} Arrancará en ${ACTIVE_DM^^} → ${DETECTED_DE^^}                                       ${NC}"
echo -e "${VERDE} Log: $LOG_FILE                                                              ${NC}"
echo -e "${VERDE}==============================================================================${NC}"
sleep 30
reboot
