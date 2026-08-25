#!/usr/bin/env bash
# ==============================================================================
#  SCRIPT: KDE PLASMA MÍNIMO ESENCIAL - FEDORA 44 (BLINDADO)
#  Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
#  Filosofía: Solo lo imprescindible para un escritorio funcional.
# ==============================================================================

set -e

VERDE='\033[0;32m'
ANUNCIAR='\033[1;34m'
ROJO='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}Ejecuta con sudo: sudo $0${NC}"
    exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$REAL_USER)
LOG_FILE="$USER_HOME/fedora_kde_minimal.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${VERDE}[OK] $2${NC}"
        echo "✅ $2" >> "$LOG_FILE"
    else
        echo -e "${ROJO}[ERROR] $2${NC}"
        echo "❌ $2" >> "$LOG_FILE"
    fi
}

echo -e "${ANUNCIAR}=== INSTALANDO KDE PLASMA MÍNIMO ESENCIAL ===${NC}"
echo "=== KDE PLASMA MÍNIMO ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Usuario: $REAL_USER" >> "$LOG_FILE"

# 1. OPTIMIZAR DNF
echo -e "${ANUNCIAR}1. Optimizando DNF...${NC}"
cat << 'EOF' > /etc/dnf/dnf.conf
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=True
max_parallel_downloads=10
defaultyes=True
EOF
log_status $? "DNF optimizado"

# 2. REPOSITORIOS
echo -e "${ANUNCIAR}2. Instalando repositorios...${NC}"
/usr/bin/dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
/usr/bin/dnf -y install dnf-plugins-core flatpak
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo | tee /etc/yum.repos.d/tailscale.repo > /dev/null
log_status $? "Repositorios instalados"

# 3. ACTUALIZAR SISTEMA
echo -e "${ANUNCIAR}3. Actualizando sistema...${NC}"
/usr/bin/dnf -y update
log_status $? "Sistema actualizado"

# 4. INSTALAR KDE PLASMA MÍNIMO (SIN APLICACIONES EXTRA)
echo -e "${ANUNCIAR}4. Instalando KDE Plasma mínimo...${NC}"
/usr/bin/dnf install -y \
    plasma-desktop \
    plasma-workspace \
    plasma-workspace-x11 \
    plasma-workspace-wayland \
    plasma-login-manager \
    dolphin \
    konsole \
    kate \
    systemsettings \
    plasma-systemmonitor \
    plasma-nm \
    plasma-pa \
    kscreen \
    kscreenlocker \
    kwalletmanager \
    xdg-desktop-portal-kde \
    pipewire pipewire-pulse wireplumber \
    gvfs gvfs-mtp gvfs-archive \
    xdg-user-dirs xdg-user-dirs-gtk \
    openssl \
    --exclude=kde-connect --exclude=akregator --exclude=kmail --exclude=kontact

systemctl enable plasmalogin
systemctl set-default graphical.target
log_status $? "KDE Plasma mínimo instalado"

# 5. ELIMINAR BLOATWARE (AGRUPADO Y POR PAQUETES)
echo -e "${ANUNCIAR}5. Eliminando todo lo no indispensable...${NC}"

# 5a. Eliminar grupos completos (los más pesados)
/usr/bin/dnf group remove -y \
    kde-apps \
    kde-media \
    kde-pim \
    kde-education \
    kde-games \
    kde-office \
    kde-network \
    desktop-accessibility \
    dial-up \
    firefox \
    guest-desktop-agents \
    input-methods \
    printing \
    standard

# 5b. Eliminar paquetes específicos que pudieran haber quedado
# (Se quitaron thermald y power-profiles-daemon para proteger la gestión térmica y de energía)
/usr/bin/dnf remove -y \
    discover \
    discover-notifier \
    plasma-discover \
    plasma-discover-notifier \
    PackageKit \
    PackageKit-command-not-found \
    PackageKit-gtk3-module \
    packagekit \
    yelp \
    kmahjongg \
    kmines \
    kpat \
    kfourinline \
    kblocks \
    ksnakeduel \
    kturtle \
    kalgebra \
    kanagram \
    kwordquiz \
    parley \
    elisa \
    juk \
    dragonplayer \
    kontact \
    kmail \
    korganizer \
    akregator \
    kaddressbook \
    konversation \
    kgpg \
    kleopatra \
    ktorrent \
    transmission \
    krdp \
    krfb \
    kdenetwork-filesharing \
    kdeplasma-addons \
    khelpcenter \
    kinfocenter \
    kfind \
    kcharselect \
    plasma-vault \
    plasma-thunderbolt \
    plasma-print-manager \
    cups-pk-helper \
    abrt \
    abrt-desktop \
    fwupd

/usr/bin/dnf autoremove -y
# Forzar reinstalación de Dolphin por si se eliminó accidentalmente
/usr/bin/dnf install -y dolphin
rm -rf "$USER_HOME/.local/share/discover" "$USER_HOME/.cache/discover" /var/cache/PackageKit
log_status $? "Bloatware eliminado"

# 6. HERRAMIENTAS ESENCIALES (solo las mínimas)
echo -e "${ANUNCIAR}6. Instalando herramientas básicas...${NC}"
/usr/bin/dnf -y install \
    xz bzip2 unrar p7zip wl-clipboard xclip \
    lbzip2 lzma arj lzop cpio git webp-pixbuf-loader \
    unar file-roller curl cabextract \
    fontconfig btop nano tailscale \
    ripgrep fd-find fastfetch
sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.nanorc"
log_status $? "Herramientas esenciales instaladas"

# 7. FISH SHELL (opcional, pero ligero y práctico)
echo -e "${ANUNCIAR}7. Configurando Fish shell...${NC}"
/usr/bin/dnf install -y fish
grep -q "/bin/fish" /etc/shells || echo "/bin/fish" >> /etc/shells
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
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/fish"
log_status $? "Fish configurado"

# 8. FUENTES BÁSICAS
echo -e "${ANUNCIAR}8. Instalando fuentes...${NC}"
/usr/bin/dnf install -y \
    google-noto-sans-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme adwaita-cursor-theme
log_status $? "Fuentes instaladas"

# 9. CÓDECS Y DRIVERS INTEL (imprescindible para hardware)
echo -e "${ANUNCIAR}9. Instalando códecs y drivers Intel...${NC}"
/usr/bin/dnf remove -y \
    ffmpeg-free libavcodec-free libavformat-free libavutil-free \
    libswscale-free libswresample-free libpostproc-free
/usr/bin/dnf install -y ffmpeg ffmpeg-libs libavdevice --allowerasing
/usr/bin/dnf install -y \
    libfreeaptx libldac fdk-aac \
    gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav
/usr/bin/dnf install -y intel-media-driver libva-utils libva-intel-driver --skip-unavailable
/usr/bin/dnf config-manager setopt fedora-cisco-openh264.enabled=1
/usr/bin/dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
log_status $? "Códecs y drivers instalados"

# 10. ZRAM Y SYSCTL (optimizaciones de bajo nivel)
echo -e "${ANUNCIAR}10. Configurando ZRAM...${NC}"
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
log_status $? "ZRAM configurado"

# 11. GuC/HuC INTEL
echo -e "${ANUNCIAR}11. Habilitando GuC/HuC...${NC}"
cat << 'EOF' > /etc/modprobe.d/i915.conf
options i915 enable_guc=2
options i915 enable_fbc=1
options i915 modeset=1
EOF
log_status $? "GuC/HuC habilitados"

# 12. FIREWALL Y TECLADO
echo -e "${ANUNCIAR}12. Configurando firewall y teclado...${NC}"
# KDE Connect en el firewall
if /usr/bin/rpm -q firewalld &>/dev/null; then
    firewall-cmd --permanent --add-service=kdeconnect
    firewall-cmd --reload
fi

localectl set-x11-keymap latam pc105
sed -i '/XKB_DEFAULT_/d' /etc/environment 2>/dev/null || true
cat << 'EOF' >> /etc/environment
XKB_DEFAULT_LAYOUT=latam
XKB_DEFAULT_MODEL=pc105
EOF
/usr/bin/systemctl disable NetworkManager-wait-online.service
/usr/bin/systemctl enable fstrim.timer
log_status $? "Firewall y teclado configurados"

# 13. OPTIMIZACIÓN AVANZADA DE KDE (Actualizado a kwriteconfig6 para Plasma 6)
echo -e "${ANUNCIAR}13. Optimizando KDE al máximo...${NC}"
sudo -u "$REAL_USER" bash -c '
    # Desactivar composición y efectos
    kwriteconfig6 --file ~/.config/kwinrc --group Compositing --key Enabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Compositing --key OpenGLIsUnsafe false
    kwriteconfig6 --file ~/.config/kwinrc --group Compositing --key GLCore false
    # Desactivar todos los plugins de efectos
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key blurEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_translucencyEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_dimscreenEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_fadedesktopEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_scaleinEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_squashEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_zoomEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_slideEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_fadeEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_coverEnabled false
    kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_glideEnabled false
    # Reducir escritorios virtuales a 1
    kwriteconfig6 --file ~/.config/kwinrc --group Desktops --key Number 1
    # Desactivar animación de cambio de escritorio
    kwriteconfig6 --file ~/.config/kwinrc --group Windows --key DesktopSwitchingAnimation 0
    # Configurar Dolphin sin previsualizaciones
    kwriteconfig6 --file ~/.config/dolphinrc --group General --key ShowThumbnails false
    kwriteconfig6 --file ~/.config/dolphinrc --group General --key PreviewSettings "application/octet-stream"
    # Desactivar animaciones del panel
    kwriteconfig6 --file ~/.config/plasmashellrc --group General --key animate 0
    # Desactivar efectos de apertura de ventanas
    kwriteconfig6 --file ~/.config/kwinrc --group Windows --key WindowOpenCloseAnimation 0
'
log_status $? "KDE optimizado"

# 14. DESACTIVAR SERVICIOS INNECESARIOS
echo -e "${ANUNCIAR}14. Deshabilitando servicios en segundo plano...${NC}"
systemctl disable --now packagekit.service 2>/dev/null || true
systemctl mask packagekit.service 2>/dev/null || true
systemctl disable --now ModemManager.service 2>/dev/null || true
systemctl disable --now avahi-daemon.service 2>/dev/null || true
systemctl disable --now switcheroo-control.service 2>/dev/null || true
systemctl disable --now cups.service 2>/dev/null || true
# Desactivar baloo (indexación) definitivamente
sudo -u "$REAL_USER" balooctl6 suspend
sudo -u "$REAL_USER" balooctl6 disable
rm -rf "$USER_HOME/.local/share/baloo"
log_status $? "Servicios innecesarios desactivados"

# 15. TWEAKS DE RENDIMIENTO (CPU y E/S)
echo -e "${ANUNCIAR}15. Aplicando tweaks de rendimiento...${NC}"
sudo mkdir -p /etc/systemd/system/user@.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/user@.service.d/99-cpu-priority.conf > /dev/null
[Service]
Nice=-5
OOMScoreAdjust=-500
EOF
sudo systemctl daemon-reload
cat << 'EOF' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
sudo udevadm control --reload-rules
log_status $? "Tweaks de rendimiento aplicados"

# 16. LIMPIEZA FINAL
echo -e "${ANUNCIAR}16. Limpiando y reconstruyendo initramfs...${NC}"
/usr/bin/dnf clean all
/usr/sbin/dracut --force -v || log_status 1 "Dracut"
echo "=== Hardware Post-Install ===" >> "$LOG_FILE"
/usr/bin/dmesg | grep -iE "guc|huc" >> "$LOG_FILE" 2>&1 || true
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || true
log_status $? "Limpieza completada"
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Sistema KDE mínimo instalado con éxito" >> "$LOG_FILE"
chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}¡SISTEMA KDE MÍNIMO LISTO!${NC}"
echo -e "${VERDE}El sistema arrancará con Plasma (sin efectos).${NC}"
echo -e "${VERDE}Puedes instalar después cualquier aplicación extra.${NC}"
echo -e "${VERDE}========================================${NC}"
echo ""
read -p "Presiona ENTER para reiniciar ahora (o Ctrl+C para cancelar)..."
reboot
