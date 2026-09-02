#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: POST-INSTALACIÓN Y OPTIMIZACIÓN - FEDORA 44 (BLINDADO)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# Filosofía: Repositorios, herramientas, códecs, ZRAM y tweaks. SIN escritorio.
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
LOG_FILE="$USER_HOME/fedora_optimizacion.log"

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
echo -e "${ANUNCIAR}=== OPTIMIZACIÓN DEL SISTEMA BASE ===${NC}"
echo -e "${ANUNCIAR}========================================${NC}"
echo "=== OPTIMIZACIÓN POST-INSTALACIÓN ===" > "$LOG_FILE"
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
# 2. REPOSITORIOS (RPM Fusion, Flatpak, Tailscale)
# ==============================================================================
echo -e "${ANUNCIAR}=== 2. INSTALANDO REPOSITORIOS ===${NC}"
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
echo -e "${ANUNCIAR}=== 3. ACTUALIZANDO SISTEMA ===${NC}"
/usr/bin/dnf -y upgrade --refresh
log_status $? "Sistema actualizado"

# ==============================================================================
# 4. LIMPIEZA DE BLOATWARE BASE
# ==============================================================================
echo -e "${ANUNCIAR}=== 4. ELIMINANDO BLOATWARE BASE ===${NC}"
/usr/bin/dnf remove -y yelp cheese gnome-contacts simple-scan gnome-tour 2>/dev/null || true
log_status $? "Bloatware base eliminado"

# ==============================================================================
# 5. HERRAMIENTAS DE SISTEMA ESENCIALES
# ==============================================================================
echo -e "${ANUNCIAR}=== 5. INSTALANDO HERRAMIENTAS ===${NC}"
/usr/bin/dnf -y install \
    xz bzip2 unrar p7zip zip wl-clipboard lbzip2 lzma arj lzop \
    cpio git webp-pixbuf-loader unar file-roller curl cabextract \
    fontconfig btop nano tailscale brightnessctl pamixer \
    jq lm_sensors loupe labwc-tweaks

sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" > "$USER_HOME/.nanorc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.nanorc"
log_status $? "Herramientas instaladas"

# ==============================================================================
# 6. FISH SHELL
# ==============================================================================
echo -e "${ANUNCIAR}=== 6. CONFIGURANDO FISH SHELL ===${NC}"
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
# 7. FUENTES
# ==============================================================================
echo -e "${ANUNCIAR}=== 7. INSTALANDO FUENTES ===${NC}"
/usr/bin/dnf install -y \
    google-noto-sans-fonts google-noto-serif-fonts liberation-fonts \
    fira-code-fonts rsms-inter-fonts papirus-icon-theme
log_status $? "Fuentes instaladas"

# ==============================================================================
# 8. CÓDECS Y DRIVERS INTEL
# ==============================================================================
echo -e "${ANUNCIAR}=== 8. INSTALANDO CÓDECS Y DRIVERS INTEL ===${NC}"
/usr/bin/dnf install -y ffmpeg ffmpeg-libs libavdevice --allowerasing
/usr/bin/dnf install -y \
    libfreeaptx libldac fdk-aac \
    gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav

/usr/bin/dnf install -y intel-media-driver libva-utils libva-intel-driver --skip-unavailable
/usr/bin/dnf config-manager setopt fedora-cisco-openh264.enabled=1
/usr/bin/dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
log_status $? "Códecs y drivers instalados"

# ==============================================================================
# 9. ZRAM Y SYSCTL (Optimización de RAM para 8GB)
# ==============================================================================
echo -e "${ANUNCIAR}=== 9. CONFIGURANDO ZRAM ===${NC}"
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
# 10. GuC/HuC INTEL (Aceleración por hardware)
# ==============================================================================
echo -e "${ANUNCIAR}=== 10. HABILITANDO GuC/HuC ===${NC}"
cat << 'EOF' > /etc/modprobe.d/i915.conf
options i915 enable_guc=2
options i915 enable_fbc=1
options i915 modeset=1
EOF
log_status $? "GuC/HuC habilitados"

# ==============================================================================
# 11. FIREWALL Y TECLADO (LATAM)
# ==============================================================================
echo -e "${ANUNCIAR}=== 11. CONFIGURANDO FIREWALL Y TECLADO ===${NC}"
if /usr/bin/rpm -q firewalld &>/dev/null; then
    firewall-cmd --permanent --add-service=kdeconnect
    firewall-cmd --permanent --add-port=53317/tcp
    firewall-cmd --permanent --add-port=53317/udp
    firewall-cmd --permanent --add-port=53318/tcp
    firewall-cmd --permanent --add-port=53318/udp
    firewall-cmd --reload
fi

# Configurar teclado a nivel sistema (funciona en X11, Wayland y TTY)
localectl set-x11-keymap latam pc105
sed -i '/XKB_DEFAULT_/d' /etc/environment 2>/dev/null || true
cat << 'EOF' >> /etc/environment
XKB_DEFAULT_LAYOUT=latam
XKB_DEFAULT_MODEL=pc105
EOF

/usr/bin/systemctl disable NetworkManager-wait-online.service
/usr/bin/systemctl enable fstrim.timer
/usr/bin/systemctl enable tailscaled
log_status $? "Firewall y teclado (latam) configurados"

# ==============================================================================
# 12. CONFIGURAR TECLADO NATIVO PARA LABWC (WAYLAND)
# ==============================================================================
echo -e "${ANUNCIAR}=== 12. CONFIGURANDO TECLADO PARA LABWC ===${NC}"

# Crear el directorio de configuración de labwc para el usuario
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/labwc"

# Crear el archivo rc.xml con la estructura XML válida para labwc
cat << 'EOF' > "$USER_HOME/.config/labwc/rc.xml"
<?xml version="1.0" encoding="UTF-8"?>
<labwc_config>
  <keyboard>
    <xkbLayout>latam</xkbLayout>
    <xkbModel>pc105</xkbModel>
  </keyboard>
</labwc_config>
EOF

# Asegurar permisos correctos
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/labwc"
log_status $? "Teclado labwc configurado en latam"

# ==============================================================================
# 13. OPTIMIZACIÓN DEL SISTEMA (Tweaks de rendimiento)
# ==============================================================================
echo -e "${ANUNCIAR}=== 13. OPTIMIZANDO SISTEMA ===${NC}"
# Enmascarar servicios de indexación pesados (Tracker)
sudo -u "$REAL_USER" systemctl --user mask \
    tracker-extract-3.service tracker-miner-fs-3.service tracker-writeback-3.service \
    evolution-addressbook-factory.service evolution-calendar-factory.service \
    evolution-source-registry.service 2>/dev/null || true

# Deshabilitar servicios del sistema innecesarios
sudo systemctl disable --now colord.service packagekit.service ModemManager.service switcheroo-control.service 2>/dev/null || true

# Cambiar a power-profiles-daemon (más ligero que tuned)
/usr/bin/dnf -y swap tuned-ppd power-profiles-daemon 2>/dev/null || true
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
log_status $? "Sistema optimizado y tweaks aplicados"

# ==============================================================================
# 14. LIMPIEZA FINAL Y DRACUT
# ==============================================================================
echo -e "${ANUNCIAR}=== 14. LIMPIEZA FINAL ===${NC}"
/usr/bin/dnf clean all
/usr/sbin/dracut --force -v || log_status 1 "Dracut"

echo "=== Hardware Post-Install ===" >> "$LOG_FILE"
/usr/bin/dmesg | grep -iE "guc|huc" >> "$LOG_FILE" 2>&1 || true
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || true
log_status $? "Limpieza y Dracut completados"

# ==============================================================================
# 15. CONFIGURAR BOOT VERBOSO (Sin quiet ni splash)
# ==============================================================================
echo -e "${ANUNCIAR}=== 15. CONFIGURANDO BOOT VERBOSO ===${NC}"
sed -i 's/ quiet//g; s/ splash//g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
log_status $? "Boot verbose configurado"

echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}¡OPTIMIZACIÓN DEL SISTEMA BASE COMPLETA!${NC}"
echo -e "${VERDE}El sistema está listo para instalar el escritorio.${NC}"
echo -e "${VERDE}Teclado configurado en: Español (Latam)${NC}"
echo -e "${VERDE}========================================${NC}"
echo ""
read -p "Presiona ENTER para reiniciar el sistema ahora (o Ctrl+C para cancelar)..." reboot
