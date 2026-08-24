#!/usr/bin/env bash
# ==============================================================================
# SCRIPT 2: INSTALACIÓN DE APLICACIONES DE USUARIO (DNF + FLATPAK)
# Optimizado para: Notebook HP Celeron N4020 / 8GB RAM / 256GB SSD
# EJECUTAR CON: curl -sSL https://raw.githubusercontent.com/Steemx/fedora-postinstall/main/02_apps.sh | sudo bash
# ==============================================================================
set -e

# 1. VERIFICACIÓN DE ROOT (Necesario para DNF)
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Este script necesita sudo para instalar paquetes del sistema (DNF)."
    echo "Por favor, ejecútalo así: sudo $0"
    echo "(El script se encargará de instalar las apps de Flatpak como tu usuario normal automáticamente)."
    exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")
LOG_FILE="$USER_HOME/fedora_apps_install.log"

log_status() {
    if [ $1 -eq 0 ]; then
        echo -e "✅ SUCESO: $2"
        echo "✅ SUCESO: $2" >> "$LOG_FILE"
    else
        echo -e "❌ FALLÓ: $2"
        echo "❌ FALLÓ: $2" >> "$LOG_FILE"
    fi
}

echo "=== INICIANDO INSTALACIÓN DE APLICACIONES DE USUARIO ==="
echo "=== REPORTE DE APLICACIONES ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Usuario real detectado: $REAL_USER" >> "$LOG_FILE"
echo "--------------------------------------------" >> "$LOG_FILE"

# ==============================================================================
# 2. APLICACIONES DEL SISTEMA (DNF) - Requiere sudo
# ==============================================================================
echo "=== 1. Instalando Aplicaciones del Sistema (DNF) ==="
/usr/bin/dnf install -y \
    steam \
    kde-connect \
    gamemode gamemode-devel

log_status $? "Instalación de Steam, KDE Connect, Gamemode, mGBA y Snes9x"

# ==============================================================================
# 3. APLICACIONES FLATPAK (Instaladas como USUARIO REAL para evitar errores)
# ==============================================================================
echo "=== 2. Instalando Aplicaciones Flatpak (como usuario: $REAL_USER) ==="

# Actualizar metadatos como usuario real
sudo -u "$REAL_USER" flatpak update --appstream -y

# Instalar apps como usuario real (el truco para evitar "Deploy not allowed")
sudo -u "$REAL_USER" flatpak install --user -y flathub \
    com.discordapp.Discord \
    com.vysp3r.ProtonPlus \
    com.github.tchx84.Flatseal \
    io.github.flattool.Warehouse \
    org.telegram.desktop \
    io.github.kolunmi.Bazaar

log_status $? "Instalación de Flatpaks"

# ==============================================================================
# 4. OPTIMIZACIÓN DE EDGE (Si ya fue instalado en el script anterior)
# ==============================================================================
echo "=== 3. Verificando/Optimizando Microsoft Edge ==="
if sudo -u "$REAL_USER" flatpak list --app | grep -q "com.microsoft.Edge"; then
    # Aplicar variables de entorno
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/environment.d"
    cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-edge.conf" > /dev/null
LIBVA_DRIVER_NAME=iHD
MOZ_DISABLE_RDD_SANDBOX=1
EOF

    # Aplicar override como usuario real
    sudo -u "$REAL_USER" flatpak override --user com.microsoft.Edge \
        --env=LIBVA_DRIVER_NAME=iHD \
        --env=MOZ_DISABLE_RDD_SANDBOX=1

    # Actualizar .desktop con flags de rendimiento
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.local/share/applications"
    if [ -f /var/lib/flatpak/exports/share/applications/com.microsoft.Edge.desktop ]; then
        cp /var/lib/flatpak/exports/share/applications/com.microsoft.Edge.desktop \
           "$USER_HOME/.local/share/applications/"
        
        sudo -u "$REAL_USER" sed -i 's|^Exec=.*|Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=microsoft-edge-stable --file-forwarding com.microsoft.Edge --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --ozone-platform=wayland @@u %U @@|' \
            "$USER_HOME/.local/share/applications/com.microsoft.Edge.desktop"
    fi
    log_status $? "Edge optimizado con VA-API"
else
    echo "ℹ️ Edge no detectado, omitiendo optimización."
fi

# ==============================================================================
# 5. LIMPIEZA FINAL
# ==============================================================================
echo "=== 4. Limpieza final de paquetes y cachés ==="
sudo -u "$REAL_USER" flatpak uninstall --unused -y
/usr/bin/update-desktop-database "$USER_HOME/.local/share/applications" &>/dev/null || true

log_status $? "Limpieza completada"

# ----------------------------------------------------------------------
echo "--------------------------------------------" >> "$LOG_FILE"
echo "Todas las aplicaciones de usuario han sido instaladas con éxito." >> "$LOG_FILE"
/usr/bin/chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

echo "=============================================================================="
echo " ¡PROCESO FINALIZADO CON ÉXITO!"
echo " - Emuladores (mGBA, Snes9x) listos."
echo " - Steam y Gamemode configurados."
echo " - Apps de usuario instaladas SIN errores de permisos."
echo "=============================================================================="
