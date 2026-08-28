#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: NIRI + NOCTALIA - FEDORA 44 (INSTALACIÓN LIMPIA DESDE CERO)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# Filosofía: Minimalismo extremo. Solo compositor + herramientas esenciales.
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

echo -e "${ANUNCIAR}=== INICIANDO INSTALACIÓN LIMPIA: NIRI + NOCTALIA ===${NC}"
echo "=== NIRI + NOCTALIA ===" > "$LOG_FILE"
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
# 4. INSTALAR BASE MÍNIMA (Niri + Esenciales)
# ==============================================================================
echo -e "${ANUNCIAR}4. Instalando base mínima Niri...${NC}"
/usr/bin/dnf install -y \
    niri \
    gdm dbus-x11 \
    waybar fuzzel mako swaybg swayidle swaylock \
    xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
    gnome-keyring \
    pipewire pipewire-pulse wireplumber \
    NetworkManager network-manager-applet \
    bluez blueman \
    gvfs gvfs-mtp gvfs-archive \
    nautilus ptyxis gnome-text-editor gnome-calculator \
    xdg-user-dirs xdg-user-dirs-gtk openssl \
    kde-connect adwaita-qt6

# Intentar instalar 'noctalia' si está en los repos, si no, no fallará el script
/usr/bin/dnf install -y noctalia 2>/dev/null || echo -e "${ANUNCIAR}[INFO] Paquete 'noctalia' no encontrado, se usará Adwaita-dark como base.${NC}"

systemctl enable gdm.service
systemctl enable --now NetworkManager.service
systemctl enable --now bluetooth.service
systemctl set-default graphical.target
log_status $? "Base mínima instalada"

# ==============================================================================
# 5. LIMPIEZA AGRESIVA DE BLOATWARE
# ==============================================================================
echo -e "${ANUNCIAR}5. Eliminando bloatware de GNOME/KDE...${NC}"
/usr/bin/dnf remove -y \
    gnome-software gnome-software-rpm-ostree \
    packagekit packagekit-gtk3-module PackageKit-command-not-found \
    yelp gnome-contacts simple-scan gnome-tour \
    gnome-shell gnome-session gnome-control-center gnome-settings-daemon \
    mutter gnome-terminal rxvt-unicode 2>/dev/null || true

/usr/bin/dnf autoremove -y
/usr/bin/dnf install -y nautilus # Protección crítica
rm -rf /var/cache/PackageKit
log_status $? "Limpieza completada"

# ==============================================================================
# 6. HERRAMIENTAS DE SISTEMA
# ==============================================================================
echo -e "${ANUNCIAR}6. Instalando herramientas...${NC}"
/usr/bin/dnf -y install \
    xz zip bzip2 unrar p7zip wl-clipboard lbzip2 lzma arj lzop \
    cpio git webp-pixbuf-loader unar file-roller curl cabextract \
    fontconfig btop nano tailscale brightnessctl pamixer \
    grim slurp jq
sudo -u "$REAL_USER" xdg-user-dirs-update
echo "set linenumbers" >> "$USER_HOME/.nanorc"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.nanorc"
log_status $? "Herramientas instaladas"

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
cat << 'EOF' >> /etc/environment
XKB_DEFAULT_LAYOUT=latam
XKB_DEFAULT_MODEL=pc105
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

# Apagar instantáneo (ignorar inhibidores de apps)
sudo sed -i 's/^#*InhibitDelayMaxSec=.*/InhibitDelayMaxSec=0/' /etc/systemd/logind.conf
log_status $? "Tweaks aplicados"

# ==============================================================================
# 14. CONFIGURACIÓN DE NIRI (config.kdl)
# ==============================================================================
echo -e "${ANUNCIAR}14. Configurando Niri...${NC}"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/niri"
cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/niri/config.kdl" > /dev/null
// Configuración Niri optimizada para Celeron N4020 + Tema Oscuro

environment {
    MOZ_ENABLE_WAYLAND "1"
    QT_QPA_PLATFORM "wayland"
    XDG_CURRENT_DESKTOP "niri"
    XDG_SESSION_TYPE "wayland"
    EDITOR "nano"
}

input {
    keyboard { xkb { layout "latam" } }
    touchpad { tap, natural-scroll, dwt }
    focus-follows-mouse max-scroll-amount="0.0"
}

layout {
    focus-ring { width 2; active-color "#89b4fa"; inactive-color "#45475a" }
    border { width 0 }
    center-focused-column "never"
    preset-column-widths { proportion 1.0; proportion 0.5; proportion 0.33333 }
    default-column-width { proportion 0.5 }
    gaps 8
}

// Animaciones desactivadas para máximo rendimiento
animations { slowdown 0.0 }

// Apps que abren flotantes
window-rule {
    match app-id="^(org.kde.kdeconnect|com.github.rafostar.Clapper|org.gnome.Calculator)$"
    open-floating true
}

binds {
    Mod+Return { spawn "ptyxis"; }
    Mod+D { spawn "fuzzel"; }
    Mod+Q { close-window; }
    Mod+L { spawn "swaylock"; }
    Mod+Shift+E { exit; }

    // Navegación estilo Vim
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+K { focus-window-up; }
    Mod+J { focus-window-down; }

    // Mover ventanas
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }
    Mod+Shift+K { move-window-up; }
    Mod+Shift+J { move-window-down; }

    // Workspaces (1-5)
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }

    // Multimedia y brillo
    XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05+" "-l" "1.0"; }
    XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05-"; }
    XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
    XF86MonBrightnessUp { spawn "brightnessctl" "set" "+5%"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }
}

// Autostart
spawn-at-startup "waybar"
spawn-at-startup "mako"
spawn-at-startup "swaybg" "-c" "#1e1e2e" // Color sólido oscuro elegante
spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock" "timeout" "600" "niri msg action power-off-monitors" "resume" "niri msg action do-screen-transition" "before-sleep" "swaylock"
spawn-at-startup "nm-applet" "--indicator"
spawn-at-startup "blueman-applet"
spawn-at-startup "/usr/libexec/polkit-gnome-authentication-agent-1"
EOF
log_status $? "Niri configurado"

# ==============================================================================
# 15. CONFIGURACIÓN DE WAYBAR (Estilo Noctalia/Oscuro)
# ==============================================================================
echo -e "${ANUNCIAR}15. Configurando Waybar...${NC}"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/waybar"

cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/waybar/config.jsonc" > /dev/null
{
    "layer": "top", "position": "top", "height": 32,
    "margin-top": 4, "margin-left": 8, "margin-right": 8,
    "modules-left": ["wlr/workspaces", "wlr/window"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "pulseaudio", "network", "bluetooth", "battery"],
    "wlr/workspaces": { "format": "{icon}", "format-icons": { "active": "●", "default": "○" } },
    "wlr/window": { "format": "{}", "max-length": 50 },
    "clock": { "format": "{:%H:%M | %a %d %b}", "tooltip-format": "<tt>{calendar}</tt>" },
    "pulseaudio": { "format": "{icon} {volume}%", "format-muted": "🔇", "format-icons": { "default": ["🔈", "🔉", "🔊"] }, "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    "network": { "format-wifi": "📶 {essid}", "format-ethernet": "🔗 {ifname}", "format-disconnected": "⚠ Sin red", "on-click": "nm-connection-editor" },
    "bluetooth": { "format": "🔷 {status}", "format-disabled": "", "format-connected": "🔷 {device_alias}", "on-click": "blueman-manager" },
    "battery": { "format": "{icon} {capacity}%", "format-icons": ["🪫", "🔋", "🔋", "🔋", "🔋"], "format-charging": "⚡ {capacity}%", "states": { "warning": 30, "critical": 15 } },
    "tray": { "spacing": 10 }
}
EOF

cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/waybar/style.css" > /dev/null
* { font-family: "Inter", "Noto Sans", sans-serif; font-size: 12px; min-height: 0; }
window#waybar { background: rgba(30, 30, 46, 0.85); color: #cdd6f4; border-radius: 8px; border: 1px solid rgba(137, 180, 250, 0.2); }
#workspaces button { padding: 0 8px; color: #6c7086; background: transparent; border: none; }
#workspaces button.active { color: #89b4fa; }
#workspaces button:hover { background: rgba(137, 180, 250, 0.1); }
#window, #clock, #pulseaudio, #network, #bluetooth, #battery, #tray { padding: 0 12px; color: #cdd6f4; }
#battery.warning { color: #f9e2af; }
#battery.critical { color: #f38ba8; }
#pulseaudio, #network, #bluetooth, #battery { margin-left: 4px; background: rgba(49, 50, 68, 0.6); border-radius: 6px; }
EOF
log_status $? "Waybar configurado"

# ==============================================================================
# 16. CONFIGURACIÓN DE MAKO (Notificaciones)
# ==============================================================================
echo -e "${ANUNCIAR}16. Configurando Mako...${NC}"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/mako" > /dev/null
sort=-time
layer=overlay
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#89b4fa
border-size=1
border-radius=8
padding=10
margin=10
width=350
max-visible=3
default-timeout=5000
font=Inter 11
EOF
log_status $? "Mako configurado"

# ==============================================================================
# 17. TEMA OSCURO (Noctalia / Adwaita-dark)
# ==============================================================================
echo -e "${ANUNCIAR}17. Configurando tema oscuro global...${NC}"
cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-theme.conf" > /dev/null
GTK_THEME=Adwaita-dark
QT_QPA_PLATFORMTHEME=gtk3
QT_STYLE_OVERRIDE=adwaita-dark
EOF

sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/gtk-4.0"
cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/gtk-3.0/settings.ini" > /dev/null
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-application-prefer-dark-theme=true
EOF
cp "$USER_HOME/.config/gtk-3.0/settings.ini" "$USER_HOME/.config/gtk-4.0/settings.ini"

# Tema oscuro para KDE Connect (Qt)
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.var/app/org.kde.kdeconnect/config/"
cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.var/app/org.kde.kdeconnect/config/kdeglobals" > /dev/null
[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
[General]
ColorScheme=BreezeDark
EOF
log_status $? "Tema oscuro configurado"

# ==============================================================================
# 18. LIMPIEZA FINAL Y DRACUT
# ==============================================================================
echo -e "${ANUNCIAR}18. Limpiando y reconstruyendo initramfs...${NC}"
/usr/bin/dnf clean all
/usr/sbin/dracut --force -v || log_status 1 "Dracut"

echo "=== Hardware Post-Install ===" >> "$LOG_FILE"
/usr/bin/dmesg | grep -iE "guc|huc" >> "$LOG_FILE" 2>&1 || true
/usr/bin/zramctl >> "$LOG_FILE" 2>&1 || true
log_status $? "Limpieza completada"

echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}¡INSTALACIÓN DE NIRI + NOCTALIA COMPLETADA!${NC}"
echo -e "${VERDE}En GDM, selecciona la sesión 'Niri' (engranaje abajo a la derecha).${NC}"
echo -e "${VERDE}========================================${NC}"
echo -e "${VERDE}Atajos principales:${NC}"
echo -e "${VERDE}  Super + Enter    → Terminal (Ptyxis)${NC}"
echo -e "${VERDE}  Super + D        → Lanzador (Fuzzel)${NC}"
echo -e "${VERDE}  Super + Q        → Cerrar ventana${NC}"
echo -e "${VERDE}  Super + H/J/K/L  → Navegar (estilo Vim)${NC}"
echo -e "${VERDE}  Super + 1-5      → Cambiar workspace${NC}"
echo -e "${VERDE}========================================${NC}"
echo ""
read -p "Presiona ENTER para reiniciar ahora (o Ctrl+C para cancelar)..."
reboot
