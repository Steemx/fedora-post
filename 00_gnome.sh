#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: GNOME MINIMAL - FEDORA 44 (BLINDADO Y OPTIMIZADO)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# Filosofía: GNOME ligero, rápido, sin bloatware, con Tiling Assistant y apps nativas.
# ==============================================================================
set -e

VERDE='\033[1;32m'
ANUNCIAR='\033[1;36m'
ROJO='\033[1;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}Ejecuta con sudo: sudo $0${NC}"
    exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$REAL_USER)
USER_UID=$(id -u "$REAL_USER")
LOG_FILE="$USER_HOME/fedora_gnome_system.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${VERDE}[OK] $2${NC}"
        echo "✅ $2" >> "$LOG_FILE"
    else
        echo -e "${ROJO}[ERROR] $2${NC}"
        echo "❌ $2" >> "$LOG_FILE"
    fi
}

echo -e "${ANUNCIAR}========================================${NC}"
echo -e "${ANUNCIAR}=== GNOME MINIMAL (BLINDADO) ===${NC}"
echo -e "${ANUNCIAR}========================================${NC}"
echo "=== SISTEMA BASE GNOME ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Usuario: $REAL_USER" >> "$LOG_FILE"

# ==============================================================================
# 1. OPTIMIZAR DNF
# ==============================================================================
echo -e "${ANUNCIAR}=== 1. OPTIMIZANDO DNF ===${NC}"
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
echo -e "${ANUNCIAR}=== 2. INSTALANDO REPOSITORIOS ===${NC}"
/usr/bin/dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
/usr/bin/dnf -y install dnf-plugins-core flatpak
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo | tee /etc/yum.repos.d/tailscale.repo > /dev/null

# Habilitar COPR para Tiling Assistant (esencial para tiling en GNOME)
/usr/bin/dnf copr enable -y thebeanogamer/gnome-shell-extension-tiling-assistant
log_status $? "Repositorios instalados"

# ==============================================================================
# 3. ACTUALIZAR SISTEMA
# ==============================================================================
echo -e "${ANUNCIAR}=== 3. ACTUALIZANDO SISTEMA ===${NC}"
/usr/bin/dnf -y upgrade --refresh
log_status $? "Sistema actualizado"

# ==============================================================================
# 4. INSTALAR BASE GNOME (Apps nativas: Ptyxis + GNOME Text Editor)
# ==============================================================================
echo -e "${ANUNCIAR}=== 4. INSTALANDO BASE GNOME ===${NC}"
/usr/bin/dnf install -y \
    gnome-shell gnome-session gnome-control-center gnome-settings-daemon \
    gdm nautilus gnome-tweaks gnome-keyring dbus-x11 \
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
    mutter pipewire pipewire-pulse wireplumber \
    gvfs gvfs-mtp gvfs-archive \
    xdg-user-dirs xdg-user-dirs-gtk openssl \
    gnome-shell-extension-tiling-assistant bluez fuse fuse-libs \
    ptyxis gnome-text-editor gnome-calculator gnome-system-monitor

systemctl enable gdm.service
systemctl set-default graphical.target
log_status $? "Base GNOME instalada"

# ==============================================================================
# 5. LIMPIEZA DE BLOATWARE
# ==============================================================================
echo -e "${ANUNCIAR}=== 5. ELIMINANDO BLOATWARE ===${NC}"
/usr/bin/dnf remove -y \
    gnome-software gnome-software-rpm-ostree \
    packagekit packagekit-gtk3-module PackageKit-command-not-found \
    yelp gnome-contacts simple-scan gnome-tour \
    gnome-weather gnome-maps gnome-connections cheese rygel gnome-remote-desktop \
    rxvt-unicode 2>/dev/null || true

# Protección crítica: garantizar que Nautilus se mantenga
/usr/bin/dnf install -y nautilus
rm -rf "$USER_HOME/.local/share/gnome-software" "$USER_HOME/.cache/gnome-software" /var/cache/PackageKit
log_status $? "Bloatware eliminado y Nautilus garantizado"

# ==============================================================================
# 6. HERRAMIENTAS DE SISTEMA
# ==============================================================================
echo -e "${ANUNCIAR}=== 6. INSTALANDO HERRAMIENTAS ===${NC}"
/usr/bin/dnf -y install \
    xz bzip2 unrar p7zip zip wl-clipboard lbzip2 lzma arj lzop \
    cpio git webp-pixbuf-loader unar file-roller curl cabextract \
    fontconfig btop nano tailscale brightnessctl pamixer \
    grim slurp jq
sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.nanorc"
log_status $? "Herramientas instaladas"

# ==============================================================================
# 7. INSTALAR KDE-CONNECT (Al final para asegurar sus dependencias con RPM Fusion)
# ==============================================================================
echo -e "${ANUNCIAR}=== INSTALANDO KDE-CONNECT ===${NC}"
/usr/bin/dnf install -y kde-connect GSConnect
/usr/bin/dnf mark install kde-connect 2>/dev/null || true
log_status $? "KDE-Connect instalado y protegido"

# ==============================================================================
# 8. FISH SHELL
# ==============================================================================
echo -e "${ANUNCIAR}=== 8. CONFIGURANDO FISH SHELL ===${NC}"
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
# 9. FUENTES
# ==============================================================================
echo -e "${ANUNCIAR}=== 9. INSTALANDO FUENTES ===${NC}"
/usr/bin/dnf install -y \
    google-noto-sans-fonts google-noto-serif-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme adwaita-cursor-theme
log_status $? "Fuentes instaladas"

# ==============================================================================
# 10. CÓDECS Y DRIVERS INTEL (Primero se instalan los códecs de RPM Fusion)
# ==============================================================================
echo -e "${ANUNCIAR}=== 10. INSTALANDO CÓDECS Y DRIVERS INTEL ===${NC}"
/usr/bin/dnf install -y ffmpeg ffmpeg-libs libavdevice --allowerasing
/usr/bin/dnf install -y \
    libfreeaptx libldac fdk-aac \
    gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav

/usr/bin/dnf install -y intel-media-driver libva-utils libva-intel-driver --skip-unavailable
/usr/bin/dnf config-manager setopt fedora-cisco-openh264.enabled=1
/usr/bin/dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
log_status $? "Códecs y drivers instalados"

# ==============================================================================
# 11. ZRAM Y SYSCTL
# ==============================================================================
echo -e "${ANUNCIAR}=== 11. CONFIGURANDO ZRAM ===${NC}"
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
# 12. GuC/HuC INTEL
# ==============================================================================
echo -e "${ANUNCIAR}=== 12. HABILITANDO GuC/HuC ===${NC}"
cat << 'EOF' > /etc/modprobe.d/i915.conf
options i915 enable_guc=2
options i915 enable_fbc=1
options i915 modeset=1
EOF
log_status $? "GuC/HuC habilitados"

# ==============================================================================
# 13. FIREWALL Y TECLADO
# ==============================================================================
echo -e "${ANUNCIAR}=== 13. CONFIGURANDO FIREWALL Y TECLADO ===${NC}"
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

/usr/bin/systemctl disable NetworkManager-wait-online.service
/usr/bin/systemctl enable fstrim.timer
/usr/bin/systemctl enable tailscaled
log_status $? "Firewall y teclado configurados"

# ==============================================================================
# 14. OPTIMIZACIÓN Y TWEAKS DE GNOME
# ==============================================================================
echo -e "${ANUNCIAR}=== 14. OPTIMIZANDO GNOME ===${NC}"

# Deshabilitar animaciones y ajustar rendimiento vía gsettings
sudo -u "$REAL_USER" dbus-run-session bash -c '
gsettings set org.gnome.desktop.interface enable-animations false
gsettings set org.gnome.desktop.interface text-scaling-factor 1.0
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.mutter attach-modal-dialogs false
gsettings set org.gnome.shell always-show-log-out true
gsettings set org.gnome.nautilus.preferences show-image-thumbnails "never"
gsettings set org.gnome.nautilus.preferences thumbnail-limit 0
gsettings set org.gnome.desktop.interface enable-hot-corners false
gsettings set org.gnome.desktop.wm.preferences focus-mode "sloppy"
gsettings set org.gnome.mutter dynamic-workspaces true
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.desktop.privacy send-software-usage-stats false
'

# Enmascarar servicios de indexación pesados (Tracker)
sudo -u "$REAL_USER" systemctl --user mask \
    tracker-extract-3.service tracker-miner-fs-3.service tracker-writeback-3.service \
    evolution-addressbook-factory.service evolution-calendar-factory.service \
    evolution-source-registry.service 2>/dev/null || true

# Deshabilitar servicios del sistema innecesarios
sudo systemctl disable --now colord.service packagekit.service ModemManager.service switcheroo-control.service 2>/dev/null || true

# Cambiar a power-profiles-daemon (más ligero que tuned)
/usr/bin/dnf -y swap tuned-ppd power-profiles-daemon
systemctl enable --now power-profiles-daemon

# Tweak de prioridad CPU para sesiones de usuario
sudo mkdir -p /etc/systemd/system/user@.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/user@.service.d/99-cpu-priority.conf > /dev/null
[Service]
Nice=-5
OOMScoreAdjust=-500
EOF
sudo systemctl daemon-reload

# Planificadores de E/S para SSD/NVMe
cat << 'EOF' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
sudo udevadm control --reload-rules

log_status $? "GNOME optimizado y tweaks aplicados"

# ==============================================================================
# 15. LIMPIEZA FINAL Y DRACUT
# ==============================================================================
echo -e "${ANUNCIAR}=== 15. LIMPIEZA FINAL ===${NC}"
/usr/bin/dnf clean all
/usr/sbin/dracut --force -v || log_status 1 "Dracut"

echo "=== Hardware Post-Install ===" >> "$LOG_FILE"
/usr/bin/dmesg | grep -iE "guc|huc" >> "$LOG_FILE" 2>&1 || true
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || true
log_status $? "Limpieza y Dracut completados"

# ==============================================================================
# 16. CONFIGURAR BOOT VERBOSO (Sin quiet ni splash)
# ==============================================================================
echo -e "${ANUNCIAR}=== 16. CONFIGURANDO BOOT VERBOSO ===${NC}"
sed -i 's/ quiet//g; s/ splash//g' /etc/default/grub

# En Fedora moderno (UEFI con wrapper), siempre usar /boot/grub2/grub.cfg
grub2-mkconfig -o /boot/grub2/grub.cfg
log_status $? "Boot verbose configurado"

echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}¡SISTEMA GNOME MINIMAL LISTO!${NC}"
echo -e "${VERDE}El sistema arrancará en GDM (modo gráfico).${NC}"
echo -e "${VERDE}Activa 'Tiling Assistant' en GNOME Tweaks.${NC}"
echo -e "${VERDE}========================================${NC}"
echo ""
read -p "Presiona ENTER para reiniciar el sistema ahora (o Ctrl+C para cancelar)..."
reboot
