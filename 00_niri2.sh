#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: NIRI + NOCTALIA - FEDORA 44 (MODO TEXTO / TTY PURISTA)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# Filosofía: Minimalismo extremo. Sin greeter, arranque en TTY, lanzamiento manual.
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
USER_UID=$(id -u "$REAL_USER")
LOG_FILE="$USER_HOME/fedora_niri_install.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${VERDE}[OK] $2${NC}"
        echo "✅ $2" >> "$LOG_FILE"
    else
        echo -e "${ROJO}[ERROR] $2${NC}"
        echo "❌ $2" >> "$LOG_FILE"
    fi
}

echo -e "${ANUNCIAR}=== INICIANDO INSTALACIÓN: NIRI + NOCTALIA (MODO TTY) ===${NC}"
echo "=== NIRI + NOCTALIA (TTY) ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Usuario: $REAL_USER" >> "$LOG_FILE"

# ==============================================================================
# 1. OPTIMIZAR DNF
# ==============================================================================
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

# ==============================================================================
# 2. REPOSITORIOS
# ==============================================================================
echo -e "${ANUNCIAR}2. Instalando repositorios...${NC}"
/usr/bin/dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
/usr/bin/dnf -y install dnf-plugins-core flatpak
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo | tee /etc/yum.repos.d/tailscale.repo > /dev/null
log_status $? "Repositorios instalados"

# ==============================================================================
# 3. ACTUALIZAR SISTEMA
# ==============================================================================
echo -e "${ANUNCIAR}3. Actualizando sistema...${NC}"
/usr/bin/dnf -y upgrade --refresh
log_status $? "Sistema actualizado"

# ==============================================================================
# 4. INSTALAR BASE MÍNIMA (Sin GDM, arranque en multi-user)
# ==============================================================================
echo -e "${ANUNCIAR}4. Instalando base mínima...${NC}"
/usr/bin/dnf install -y \
    niri \
    noctalia \
    dbus-x11 \
    swaybg swayidle swaylock \
    xdg-desktop-portal-gtk \
    gnome-keyring \
    pipewire pipewire-pulse wireplumber \
    NetworkManager network-manager-applet \
    bluez blueman \
    gvfs gvfs-mtp gvfs-archive \
    nautilus ptyxis gnome-text-editor gnome-calculator \
    xdg-user-dirs xdg-user-dirs-gtk openssl \
    kde-connect

# Configurar arranque en modo texto (TTY)
systemctl set-default multi-user.target
systemctl enable --now NetworkManager.service
systemctl enable --now bluetooth.service
log_status $? "Base mínima instalada (Arranque en TTY)"

# ==============================================================================
# 5. LIMPIEZA AGRESIVA DE BLOATWARE
# ==============================================================================
echo -e "${ANUNCIAR}5. Eliminando bloatware de GNOME/KDE...${NC}"
/usr/bin/dnf remove -y \
    gnome-software gnome-software-rpm-ostree \
    packagekit packagekit-gtk3-module PackageKit-command-not-found \
    yelp gnome-contacts simple-scan gnome-tour \
    gnome-shell gnome-session gnome-control-center gnome-settings-daemon \
    gdm mutter gnome-terminal rxvt-unicode 2>/dev/null || true

/usr/bin/dnf autoremove -y
/usr/bin/dnf install -y nautilus # Protección crítica
rm -rf /var/cache/PackageKit
log_status $? "Limpieza completada"

# ==============================================================================
# 6. HERRAMIENTAS DE SISTEMA
# ==============================================================================
echo -e "${ANUNCIAR}6. Instalando herramientas...${NC}"
/usr/bin/dnf -y install \
    xz bzip2 unrar p7zip wl-clipboard lbzip2 lzma arj lzop \
    cpio git webp-pixbuf-loader unar file-roller curl cabextract \
    fontconfig btop nano tailscale brightnessctl pamixer \
    grim slurp jq zip
sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.nanorc"
log_status $? "Herramientas instaladas"

# ==============================================================================
# 7. FISH SHELL (Con alias para lanzar Niri fácilmente)
# ==============================================================================
echo -e "${ANUNCIAR}7. Configurando Fish shell...${NC}"
/usr/bin/dnf install -y fish
grep -q "/bin/fish" /etc/shells || echo "/bin/fish" >> /etc/shells
chsh -s /bin/fish "$REAL_USER"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/fish"
cat << 'EOF' > "$USER_HOME/.config/fish/config.fish"
set -g fish_greeting ""
alias update='sudo dnf upgrade -y && flatpak update -y'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
# Alias para iniciar el entorno gráfico desde la TTY
alias niri='niri-session'
alias start='niri-session'

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

# ==============================================================================
# 8. FUENTES
# ==============================================================================
echo -e "${ANUNCIAR}8. Instalando fuentes...${NC}"
/usr/bin/dnf install -y \
    google-noto-sans-fonts google-noto-serif-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme adwaita-cursor-theme
log_status $? "Fuentes instaladas"

# ==============================================================================
# 9. CÓDECS Y DRIVERS INTEL (Optimización N4020)
# ==============================================================================
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

# ==============================================================================
# 10. ZRAM Y SYSCTL (Salvavidas para 8GB RAM)
# ==============================================================================
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

# ==============================================================================
# 11. GuC/HuC INTEL
# ==============================================================================
echo -e "${ANUNCIAR}11. Habilitando GuC/HuC...${NC}"
cat << 'EOF' > /etc/modprobe.d/i915.conf
options i915 enable_guc=2
options i915 enable_fbc=1
options i915 modeset=1
EOF
log_status $? "GuC/HuC habilitados"

# ==============================================================================
# 12. FIREWALL Y VARIABLES DE ENTORNO GLOBALES
# ==============================================================================
echo -e "${ANUNCIAR}12. Configurando firewall y entorno Wayland...${NC}"
if /usr/bin/rpm -q firewalld &>/dev/null; then
    firewall-cmd --permanent --add-service=kdeconnect
    firewall-cmd --permanent --add-port=53317/tcp
    firewall-cmd --permanent --add-port=53317/udp
    firewall-cmd --permanent --add-port=53318/tcp
    firewall-cmd --permanent --add-port=53318/udp
    firewall-cmd --reload
fi

localectl set-x11-keymap latam pc105
sed -i '/XKB_DEFAULT_/d' /etc/environment 2>/dev/null || true
cat << 'EOF' >> /etc/environment
XKB_DEFAULT_LAYOUT=latam
XKB_DEFAULT_MODEL=pc105
EOF

sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/environment.d"
cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-wayland.conf" > /dev/null
XDG_CURRENT_DESKTOP=niri
XDG_SESSION_TYPE=wayland
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
EOF

/usr/bin/systemctl disable NetworkManager-wait-online.service
/usr/bin/systemctl enable fstrim.timer
log_status $? "Firewall y entorno configurados"

# ==============================================================================
# 13. TWEAKS DE RENDIMIENTO Y APAGADO INSTANTÁNEO
# ==============================================================================
echo -e "${ANUNCIAR}13. Aplicando tweaks de rendimiento...${NC}"
sudo mkdir -p /etc/systemd/system/user@.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/user@.service.d/99-cpu-priority.conf > /dev/null
[Service]
Nice=-5
OOMScoreAdjust=-500
EOF
sudo systemctl daemon-reload
sudo systemctl disable --now ModemManager.service avahi-daemon.service switcheroo-control.service packagekit.service colord.service 2>/dev/null || true

cat << 'EOF' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
sudo udevadm control --reload-rules

sudo mkdir -p /etc/systemd
if [ ! -f /etc/systemd/logind.conf ]; then
    echo -e "[Login]\nInhibitDelayMaxSec=0" | sudo tee /etc/systemd/logind.conf > /dev/null
else
    sudo sed -i 's/^#*InhibitDelayMaxSec=.*/InhibitDelayMaxSec=0/' /etc/systemd/logind.conf
fi
log_status $? "Tweaks aplicados"

# ==============================================================================
# 14. CONFIGURACIÓN DE NIRI
# ==============================================================================
echo -e "${ANUNCIAR}14. Configurando Niri...${NC}"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/niri"

# Copiar configuración original de Niri
cp /usr/share/doc/niri/default.config.kdl "$USER_HOME/.config/niri/config.kdl"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/niri/config.kdl"

# Agregar Noctalia al autostart
echo 'spawn-at-startup "noctalia"' >> "$USER_HOME/.config/niri/config.kdl"

log_status $? "Niri configurado"

# ==============================================================================
# 15. LIMPIEZA FINAL Y DRACUT
# ==============================================================================
echo -e "${ANUNCIAR}15. Limpiando y reconstruyendo initramfs...${NC}"
/usr/bin/dnf clean all
/usr/sbin/dracut --force -v || log_status 1 "Dracut"

echo "=== Hardware Post-Install ===" >> "$LOG_FILE"
/usr/bin/dmesg | grep -iE "guc|huc" >> "$LOG_FILE" 2>&1 || true
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || true
log_status $? "Limpieza completada"

echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}¡INSTALACIÓN COMPLETADA (MODO TTY)!${NC}"
echo -e "${VERDE}Al reiniciar, verás la terminal de login (TTY).${NC}"
echo -e "${VERDE}Inicia sesión con tu usuario y contraseña.${NC}"
echo -e "${VERDE}Luego, escribe 'niri' o 'start' y presiona Enter.${NC}"
echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}Atajos principales en Niri:${NC}"
echo -e "${VERDE}  Super + T    → Terminal (Ptyxis)${NC}"
echo -e "${VERDE}  Super + Q        → Cerrar ventana${NC}"
echo -e "${VERDE}  Super + H/J/K/L  → Navegar (estilo Vim)${NC}"
echo -e "${VERDE}  Super + 1-5      → Cambiar workspace${NC}"
echo -e "${VERDE}========================================${NC}"
echo ""
read -p "Presiona ENTER para reiniciar ahora (o Ctrl+C para cancelar)..."
reboot
