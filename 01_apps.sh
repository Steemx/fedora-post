#!/usr/bin/env bash
# ==============================================================================
# SCRIPT 2: APLICACIONES FLATPAK - SIN ROOT
# EJECUTAR COMO USUARIO NORMAL: curl -sSL https://raw.githubusercontent.com/Steemx/fedora-postinstall/main/02_apps.sh | bash
# ==============================================================================

set -e

# NO ejecutar como root
if [ "$EUID" -eq 0 ]; then
    echo "❌ NO ejecutes este script con sudo"
    echo "Ejecútalo como usuario normal:"
    echo "curl -sSL .../02_apps.sh | bash"
    exit 1
fi

REAL_USER=$USER
USER_HOME=$HOME
LOG_FILE="$USER_HOME/fedora_apps.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
        echo "✅ $2" >> "$LOG_FILE"
    else
        echo "❌ $2"
        echo "❌ $2" >> "$LOG_FILE"
    fi
}

echo "=== INSTALANDO APLICACIONES DE USUARIO ==="
echo "=== APLICACIONES FLATPAK ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Usuario: $REAL_USER" >> "$LOG_FILE"

# ==============================================================================
# 1. VERIFICAR FLATPAK
# ==============================================================================
echo "1. Verificando Flatpak..."
if ! command -v flatpak &> /dev/null; then
    echo "❌ Flatpak no está instalado. Ejecuta primero el script del sistema."
    exit 1
fi

if ! flatpak remotes | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
log_status $? "Flatpak verificado"

# ==============================================================================
# 2. ACTUALIZAR REPOS
# ==============================================================================
echo "2. Actualizando repositorios..."
flatpak update --appstream -y
log_status $? "Repos actualizados"

# ==============================================================================
# 3. INSTALAR APLICACIONES FLATPAK
# ==============================================================================
echo "3. Instalando aplicaciones Flatpak..."

# Edge
flatpak install -y flathub com.microsoft.Edge
log_status $? "Microsoft Edge instalado"

# GNOME Extensions
flatpak install -y flathub org.gnome.Extensions
log_status $? "GNOME Extensions instalado"

# Apps adicionales (comenta las que no quieras)
flatpak install -y flathub \
    org.telegram.desktop \
    com.discordapp.Discord \
    com.github.tchx84.Flatseal \
    io.github.flattool.Warehouse
log_status $? "Aplicaciones adicionales instaladas"

# ==============================================================================
# 4. OPTIMIZAR EDGE (VA-API + FLAGS)
# ==============================================================================
echo "4. Optimizando Edge..."

# Variables de entorno para VA-API
mkdir -p "$USER_HOME/.config/environment.d"
cat << 'EOF' > "$USER_HOME/.config/environment.d/99-edge.conf"
LIBVA_DRIVER_NAME=iHD
MOZ_DISABLE_RDD_SANDBOX=1
EOF

# Override de Flatpak como usuario (SIN sudo)
flatpak override --user com.microsoft.Edge \
    --env=LIBVA_DRIVER_NAME=iHD \
    --env=MOZ_DISABLE_RDD_SANDBOX=1

# Crear .desktop personalizado con flags
mkdir -p "$USER_HOME/.local/share/applications"
if [ -f /var/lib/flatpak/exports/share/applications/com.microsoft.Edge.desktop ]; then
    cp /var/lib/flatpak/exports/share/applications/com.microsoft.Edge.desktop \
       "$USER_HOME/.local/share/applications/"
    
    sed -i 's|^Exec=.*|Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=microsoft-edge-stable --file-forwarding com.microsoft.Edge --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --ozone-platform=wayland @@u %U @@|' \
        "$USER_HOME/.local/share/applications/com.microsoft.Edge.desktop"
fi

log_status $? "Edge optimizado"

# ==============================================================================
# 5. LIMPIEZA
# ==============================================================================
echo "5. Limpiando..."
flatpak uninstall --unused -y
log_status $? "Limpieza completada"

# ==============================================================================
# FIN
# ==============================================================================
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Aplicaciones instaladas con éxito" >> "$LOG_FILE"

echo ""
echo "========================================"
echo "¡APLICACIONES LISTAS!"
echo "========================================"
echo ""
echo "Edge está optimizado con VA-API"
echo "Reinicia sesión para aplicar cambios"
echo ""
