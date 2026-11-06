#!/usr/bin/env bash
# ==============================================================================
# SCRIPT UNIFICADO: FEDORA 44 - KDE PLASMA MÍNIMO + APPS (BLINDADO)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# Filosofía: Solo lo imprescindible para un escritorio funcional.
# Combina: 00_kde.sh + 00_appsenhanced.sh + 00_apps.sh
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
LOG_FILE="$USER_HOME/fedora_unified_install.log"

log_status() {
  if [ $1 -eq 0 ]; then
    echo -e "${VERDE}[OK] $2${NC}"
    echo "✅ $2" >> "$LOG_FILE"
  else
    echo -e "${ROJO}[ERROR] $2${NC}"
    echo "❌ $2" >> "$LOG_FILE"
  fi
}

echo -e "${ANUNCIAR}=== INSTALANDO FEDORA 44 UNIFICADO (KDE + APPS) ===${NC}"
echo "=== FEDORA 44 UNIFICADO ===" > "$LOG_FILE"
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
/usr/bin/dnf -y update
log_status $? "Sistema actualizado"

# ==============================================================================
# 4. INSTALAR KDE PLASMA MÍNIMO (SIN APLICACIONES EXTRA)
# ==============================================================================
echo -e "${ANUNCIAR}4. Instalando KDE Plasma mínimo...${NC}"
/usr/bin/dnf install -y \
  plasma-desktop \
  plasma-workspace \
  plasma-workspace-x11 \
  plasma-workspace-wayland \
  sddm \
  dolphin \
  konsole \
  kate \
  ark \
  bluedevil \
  systemsettings \
  plasma-systemmonitor \
  plasma-nm \
  plasma-pa \
  kscreen \
  kscreenlocker \
  kwalletmanager \
  xdg-desktop-portal-kde \
  pipewire pipewire-pulse wireplumber \
  gvfs gvfs-mtp \
  xdg-user-dirs xdg-user-dirs-gtk \
  openssl \
  --exclude=akregator --exclude=kmail --exclude=kontact
systemctl enable sddm
systemctl set-default graphical.target
log_status $? "KDE Plasma mínimo instalado"

# ==============================================================================
# 5. ELIMINAR BLOATWARE (AGRUPADO Y POR PAQUETES)
# ==============================================================================
echo -e "${ANUNCIAR}5. Eliminando todo lo no indispensable...${NC}"
/usr/bin/dnf group remove -y \
  kde-apps kde-media kde-pim kde-education kde-games kde-office \
  desktop-accessibility dial-up firefox guest-desktop-agents \
  input-methods printing standard

/usr/bin/dnf remove -y \
  discover discover-notifier plasma-discover plasma-discover-notifier \
  PackageKit PackageKit-command-not-found PackageKit-gtk3-module packagekit \
  yelp kmahjongg kmines kpat kfourinline kblocks ksnakeduel kturtle \
  kalgebra kanagram kwordquiz parley elisa juk dragonplayer kontact \
  kmail korganizer akregator kaddressbook konversation kgpg kleopatra \
  ktorrent transmission krdp krfb kdenetwork-filesharing kdeplasma-addons \
  khelpcenter kinfocenter kfind kcharselect plasma-vault plasma-thunderbolt \
  plasma-print-manager cups-pk-helper abrt abrt-desktop fwupd

/usr/bin/dnf autoremove -y
/usr/bin/dnf install -y dolphin # Forzar reinstalación por si se eliminó accidentalmente
rm -rf "$USER_HOME/.local/share/discover" "$USER_HOME/.cache/discover" /var/cache/PackageKit
log_status $? "Bloatware eliminado"

# ==============================================================================
# 6. HERRAMIENTAS ESENCIALES
# ==============================================================================
echo -e "${ANUNCIAR}6. Instalando herramientas básicas...${NC}"
/usr/bin/dnf -y install \
  xz bzip2 unrar p7zip wl-clipboard lbzip2 lzma arj lzop cpio git \
  webp-pixbuf-loader unar curl cabextract fontconfig btop nano tailscale \
  lm_sensors ripgrep fastfetch kde-connect bluez fuse fuse-libs
sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.nanorc"
log_status $? "Herramientas esenciales instaladas"

# ==============================================================================
# 7. FISH SHELL
# ==============================================================================
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

# ==============================================================================
# 8. FUENTES BÁSICAS
# ==============================================================================
echo -e "${ANUNCIAR}8. Instalando fuentes...${NC}"
/usr/bin/dnf install -y \
  google-noto-sans-fonts liberation-fonts fira-code-fonts \
  rsms-inter-fonts papirus-icon-theme adwaita-cursor-theme
log_status $? "Fuentes instaladas"

# ==============================================================================
# 9. CÓDECS Y DRIVERS INTEL
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
# 10. ZRAM Y SYSCTL
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
# 12. FIREWALL Y TECLADO
# ==============================================================================
echo -e "${ANUNCIAR}12. Configurando firewall y teclado...${NC}"
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
log_status $? "Firewall y teclado configurados"

# ==============================================================================
# 13. OPTIMIZACIÓN AVANZADA DE KDE
# ==============================================================================
echo -e "${ANUNCIAR}13. Optimizando KDE al máximo...${NC}"
sudo -u "$REAL_USER" bash -c '
kwriteconfig6 --file ~/.config/kwinrc --group Compositing --key Enabled false
kwriteconfig6 --file ~/.config/kwinrc --group Compositing --key OpenGLIsUnsafe false
kwriteconfig6 --file ~/.config/kwinrc --group Compositing --key GLCore false
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
kwriteconfig6 --file ~/.config/kwinrc --group Desktops --key Number 1
kwriteconfig6 --file ~/.config/kwinrc --group Windows --key DesktopSwitchingAnimation 0
kwriteconfig6 --file ~/.config/dolphinrc --group General --key ShowThumbnails false
kwriteconfig6 --file ~/.config/dolphinrc --group General --key PreviewSettings "application/octet-stream"
kwriteconfig6 --file ~/.config/plasmashellrc --group General --key animate 0
kwriteconfig6 --file ~/.config/kwinrc --group Windows --key WindowOpenCloseAnimation 0
'
log_status $? "KDE optimizado"

# ==============================================================================
# 14. DESACTIVAR SERVICIOS INNECESARIOS
# ==============================================================================
echo -e "${ANUNCIAR}14. Deshabilitando servicios en segundo plano...${NC}"
systemctl disable --now packagekit.service 2>/dev/null || true
systemctl mask packagekit.service 2>/dev/null || true
systemctl disable --now ModemManager.service 2>/dev/null || true
systemctl disable --now avahi-daemon.service 2>/dev/null || true
systemctl disable --now switcheroo-control.service 2>/dev/null || true
systemctl disable --now cups.service 2>/dev/null || true
sudo -u "$REAL_USER" balooctl6 suspend 2>/dev/null || true
sudo -u "$REAL_USER" balooctl6 disable 2>/dev/null || true
rm -rf "$USER_HOME/.local/share/baloo" 2>/dev/null || true
log_status $? "Servicios innecesarios desactivados"

# ==============================================================================
# 15. TWEAKS DE RENDIMIENTO (CPU y E/S)
# ==============================================================================
echo -e "${ANUNCIAR}15. Aplicando tweaks de rendimiento...${NC}"
mkdir -p /etc/systemd/system/user@.service.d
cat << 'EOF' | tee /etc/systemd/system/user@.service.d/99-cpu-priority.conf > /dev/null
[Service]
Nice=-5
OOMScoreAdjust=-500
EOF
systemctl daemon-reload
cat << 'EOF' | tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF
udevadm control --reload-rules
log_status $? "Tweaks de rendimiento aplicados"

# ==============================================================================
# 16. APLICACIONES DEL SISTEMA (DNF)
# ==============================================================================
echo -e "${ANUNCIAR}16. Instalando aplicaciones del sistema (DNF)...${NC}"
/usr/bin/dnf install -y steam kde-connect gamemode gamemode-devel mangohud goverlay fuse fuse-libs < /dev/null
log_status $? "Instalación de Steam, KDE Connect, Gamemode y MangoHud"

# ==============================================================================
# 17. CONFIGURANDO CARPETAS DE USUARIO
# ==============================================================================
echo -e "${ANUNCIAR}17. Configurando carpetas de usuario...${NC}"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/autostart"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.local/bin"
log_status $? "Carpetas de usuario configuradas"

# ==============================================================================
# 18. INSTALANDO APLICACIONES FLATPAK
# ==============================================================================
echo -e "${ANUNCIAR}18. Instalando aplicaciones Flatpak...${NC}"
/usr/bin/flatpak remote-delete --system fedora 2>/dev/null || true
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
/usr/bin/flatpak update --appstream -y < /dev/null
/usr/bin/flatpak install --system -y --noninteractive flathub \
  com.discordapp.Discord \
  com.vysp3r.ProtonPlus \
  com.github.tchx84.Flatseal \
  io.github.flattool.Warehouse \
  org.telegram.desktop \
  org.localsend.localsend_app \
  io.missioncenter.MissionCenter \
  io.github.kolunmi.Bazaar < /dev/null
log_status $? "Instalación de Flatpaks base"

# ==============================================================================
# 19. SELECCIÓN E INSTALACIÓN DE NAVEGADOR (CORREGIDO PARA DNF5)
# ==============================================================================
echo "=============================================================================="
echo "🌐 SELECCIÓN DE NAVEGADOR WEB"
echo "=============================================================================="
echo "1. Firefox (Nativo RPM + Optimizado para Celeron/Intel UHD 605)"
echo "2. Microsoft Edge (Nativo RPM - Más rápido y ligero)"
echo "3. Ambos"
echo "4. Omitir instalación de navegador"
echo "------------------------------------------------------------------------------"
read -p "Elige una opción [1-4]: " browser_choice

case $browser_choice in
  1|3)
    echo "=== Instalando Firefox Nativo (RPM) ==="
    /usr/bin/dnf install -y firefox
    log_status $? "Instalación de Firefox Nativo"
    echo "=== Aplicando optimizaciones de Firefox (Betterfox + Hardware) ==="
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/environment.d"
    echo "MOZ_ENABLE_WAYLAND=1" | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-firefox-wayland.conf" > /dev/null
    
    echo "Inicializando perfil de Firefox para aplicar tweaks..."
    sudo -u "$REAL_USER" timeout 5 firefox --headless >/dev/null 2>&1 || true
    sleep 2
    
    PROFILE_DIR=$(sudo -u "$REAL_USER" find "$USER_HOME/.mozilla/firefox" "$USER_HOME/.config/mozilla/firefox" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
    if [ -n "$PROFILE_DIR" ]; then
      sudo -u "$REAL_USER" curl -s -o "$PROFILE_DIR/user.js" https://raw.githubusercontent.com/yokoffing/Betterfox/main/Fastfox.js
      cat << 'EOF' | sudo -u "$REAL_USER" tee -a "$PROFILE_DIR/user.js" > /dev/null
user_pref("dom.ipc.processCount", 2);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("gfx.webrender.all", true);
EOF
      log_status 0 "Tweaks de Firefox aplicados correctamente (Betterfox + VA-API)"
    else
      log_status 1 "No se pudo generar el perfil automáticamente."
    fi

    cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.local/bin/fix-firefox-tweaks.sh" > /dev/null
#!/usr/bin/env bash
PROFILE_DIR=$(find ~/.mozilla/firefox ~/.config/mozilla/firefox -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)
if [ -n "$PROFILE_DIR" ]; then
  curl -s -o "$PROFILE_DIR/user.js" https://raw.githubusercontent.com/yokoffing/Betterfox/main/Fastfox.js
  cat << 'INNEREOF' >> "$PROFILE_DIR/user.js"
user_pref("dom.ipc.processCount", 2);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("gfx.webrender.all", true);
INNEREOF
  echo "✅ Tweaks de Firefox reaplicados correctamente."
else
  echo "⚠️ No se encontró el perfil. Abre Firefox una vez, ciérralo y vuelve a ejecutar este script."
fi
EOF
    sudo -u "$REAL_USER" chmod +x "$USER_HOME/.local/bin/fix-firefox-tweaks.sh"
    ;;
  *)
    echo "ℹ️ Firefox omitido."
    ;;
esac

case $browser_choice in
  2|3)
    echo "=== Instalando Microsoft Edge Nativo (RPM) ==="
    # CORRECCIÓN: Método compatible con DNF5 (Fedora 44)
    if [ ! -f /etc/yum.repos.d/microsoft-edge.repo ]; then
      echo "=== Agregando repositorio de Microsoft Edge ==="
      curl -s -o /etc/yum.repos.d/microsoft-edge.repo https://packages.microsoft.com/yumrepos/edge/config.repo
      rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
      log_status $? "Repositorio y clave GPG de Microsoft Edge agregados"
    fi
    
    /usr/bin/dnf install -y microsoft-edge-stable
    log_status $? "Instalación de Edge Nativo (RPM)"
    
    echo "=== Optimizando Microsoft Edge Nativo (VA-API + Wayland) ==="
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/environment.d"
    cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-edge.conf" > /dev/null
LIBVA_DRIVER_NAME=iHD
MOZ_DISABLE_RDD_SANDBOX=1
EOF

    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.local/share/applications"
    if [ -f /usr/share/applications/microsoft-edge.desktop ]; then
      cp /usr/share/applications/microsoft-edge.desktop "$USER_HOME/.local/share/applications/"
      sudo -u "$REAL_USER" sed -i 's|^Exec=.*|Exec=/usr/bin/microsoft-edge-stable --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --ozone-platform=wayland %U|' "$USER_HOME/.local/share/applications/microsoft-edge.desktop"
    fi
    
    update-desktop-database "$USER_HOME/.local/share/applications" 2>/dev/null || true
    log_status $? "Edge optimizado con VA-API y Wayland"
    
    sudo -u "$REAL_USER" xdg-mime default microsoft-edge.desktop x-scheme-handler/http
    sudo -u "$REAL_USER" xdg-mime default microsoft-edge.desktop x-scheme-handler/https
    sudo -u "$REAL_USER" xdg-mime default microsoft-edge.desktop text/html
    sudo -u "$REAL_USER" xdg-mime default microsoft-edge.desktop application/xhtml+xml
    log_status 0 "Edge establecido como navegador predeterminado"
    ;;
  *)
    echo "ℹ️ Edge omitido."
    ;;
esac

# ==============================================================================
# 20. LIMPIEZA FINAL
# ==============================================================================
echo -e "${ANUNCIAR}20. Limpiando y reconstruyendo initramfs...${NC}"
/usr/bin/flatpak uninstall --unused -y < /dev/null
/usr/bin/dnf clean all
/usr/bin/update-desktop-database /var/lib/flatpak/exports/share/applications &>/dev/null
/usr/sbin/dracut --force -v || log_status 1 "Dracut"

echo "=== Hardware Post-Install ===" >> "$LOG_FILE"
/usr/bin/dmesg | grep -iE "guc|huc" >> "$LOG_FILE" 2>&1 || true
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || true
log_status $? "Limpieza completada"
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Sistema Fedora 44 unificado instalado con éxito" >> "$LOG_FILE"
chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}¡SISTEMA FEDORA 44 UNIFICADO LISTO!${NC}"
echo -e "${VERDE}El sistema arrancará con Plasma (sin efectos).${NC}"
if [ "$browser_choice" = "1" ] || [ "$browser_choice" = "3" ]; then
  echo -e "${VERDE}💡 Firefox instalado con tweaks Betterfox + VA-API.${NC}"
  echo -e "${VERDE}💡 Si algo falla en el futuro, ejecuta: ~/.local/bin/fix-firefox-tweaks.sh${NC}"
fi
echo -e "${VERDE}========================================${NC}"
echo ""
read -p "Presiona ENTER para reiniciar ahora (o Ctrl+C para cancelar)..."
reboot
