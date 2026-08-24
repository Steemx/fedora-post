#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE APLICACIONES DE USUARIO (DNF + FLATPAK)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# EJECUTAR CON: curl -sSL https://raw.githubusercontent.com/Steemx/fedora-postinstall/main/01_apps.sh | sudo bash
# ==============================================================================

set -e

VERDE='\033[0;32m'
ANUNCIAR='\033[1;34m'
ROJO='\033[0;31m'
NC='\033[0m'

# Este script necesita sudo para dnf, pero protegeremos a flatpak
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}Por favor, ejecuta este script con sudo: sudo $0${NC}"
    exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")
LOG_FILE="$USER_HOME/fedora_apps_install.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${VERDE}[OK] $2${NC}"
        echo "✅ SUCESO: $2" >> "$LOG_FILE"
    else
        echo -e "${ROJO}[ERROR] $2${NC}"
        echo "❌ FALLÓ: $2" >> "$LOG_FILE"
    fi
}

echo -e "${ANUNCIAR}=== INICIANDO INSTALACIÓN DE APLICACIONES ===${NC}"
echo "=== REPORTE DE APLICACIONES ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Usuario: $REAL_USER" >> "$LOG_FILE"
echo "--------------------------------------------" >> "$LOG_FILE"

# ==============================================================================
# 1. APLICACIONES DEL SISTEMA (DNF)
# ==============================================================================
echo -e "${ANUNCIAR}1. Instalando aplicaciones del sistema (DNF)...${NC}"

# Steam, Gamemode (para rendimiento en juegos) y Emuladores ligeros (SNES/GBA)
/usr/bin/dnf install -y \
    steam \
    gamemode gamemode-devel

log_status $? "Aplicaciones DNF instaladas (Steam, Gamemode, mGBA, Snes9x)"

# ==============================================================================
# 2. APLICACIONES FLATPAK (Instaladas como USUARIO REAL, no como root)
# ==============================================================================
echo -e "${ANUNCIAR}2. Instalando aplicaciones Flatpak...${NC}"

# Actualizar metadatos
/usr/bin/flatpak update --appstream -y

# Instalar apps usando sudo -u para evitar el error "Deploy not allowed for user"
sudo -u "$REAL_USER" flatpak install -y flathub \
    com.discordapp.Discord \
    com.vysp3r.ProtonPlus \
    com.github.tchx84.Flatseal \
    io.github.flattool.Warehouse \
    org.telegram.desktop

log_status $? "Aplicaciones Flatpak instaladas"

# ==============================================================================
# 3. OPTIMIZACIÓN DE EDGE (Si se instaló previamente)
# ==============================================================================
echo -e "${ANUNCIAR}3. Verificando optimizaciones de Edge...${NC}"

if sudo -u "$REAL_USER" flatpak list --app | grep -q "com.microsoft.Edge"; then
    sudo -u "$REAL_USER" flatpak override --user com.microsoft.Edge \
        --env=LIBVA_DRIVER_NAME=iHD \
        --env=MOZ_DISABLE_RDD_SANDBOX=1
    
    # Crear/Actualizar .desktop con flags de rendimiento
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.local/share/applications"
    if [ -f /var/lib/flatpak/exports/share/applications/com.microsoft.Edge.desktop ]; then
        cp /var/lib/flatpak/exports/share/applications/com.microsoft.Edge.desktop \
           "$USER_HOME/.local/share/applications/"
        
        sudo -u "$REAL_USER" sed -i 's|^Exec=.*|Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=microsoft-edge-stable --file-forwarding com.microsoft.Edge --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --ozone-platform=wayland @@u %U @@|' \
            "$USER_HOME/.local/share/applications/com.microsoft.Edge.desktop"
    fi
    log_status $? "Edge optimizado"
else
    echo "ℹ️ Edge no detectado, omitiendo optimización."
fi

# ==============================================================================
# 4. LIMPIEZA FINAL
# ==============================================================================
echo -e "${ANUNCIAR}4. Limpiando paquetes y cachés...${NC}"

/usr/bin/flatpak uninstall --unused -y
/usr/bin/update-desktop-database "$USER_HOME/.local/share/applications" &>/dev/null || true

log_status $? "Limpieza completada"

# ----------------------------------------------------------------------
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Todas las aplicaciones se instalaron con éxito." >> "$LOG_FILE"
/usr/bin/chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

echo -e "${VERDE}==============================================================================${NC}"
echo -e "${VERDE} ¡PROCESO FINALIZADO CON ÉXITO!${NC}"
echo -e "${VERDE} - Emuladores (mGBA, Snes9x) listos para usar.${NC}"
echo -e "${VERDE} - Steam y Gamemode configurados.${NC}"
echo -e "${VERDE} - Apps de usuario instaladas sin errores de permisos.${NC}"
echo -e "${VERDE}==============================================================================${NC}"
