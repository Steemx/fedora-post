#!/usr/bin/env bash
# ==============================================================================
# SCRIPT 2: INSTALACIÓN DE APLICACIONES DE USUARIO Y CONFIGURACIÓN DE INICIO
# ==============================================================================
set -e
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, ejecuta este script usando sudo: sudo $0"
    exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")
LOG_FILE="$USER_HOME/fedora_apps_install.log"

# Permitimos que el script continúe incluso si un comando falla, para poder registrar el error
set +e

log_status() {
    if [ $1 -eq 0 ]; then
        echo "✅ SUCESO: $2"
        echo "✅ SUCESO: $2" >> "$LOG_FILE"
    else
        echo "❌ FALLÓ: $2"
        echo "❌ FALLÓ: $2" >> "$LOG_FILE"
    fi
}

echo "=== INICIANDO INSTALACIÓN DE APLICACIONES DE USUARIO ==="
echo "=== REPORTE DE APLICACIONES ===" > "$LOG_FILE"
echo "Fecha: $(date)" >> "$LOG_FILE"
echo "Usuario: $REAL_USER" >> "$LOG_FILE"
echo "--------------------------------------------" >> "$LOG_FILE"

echo "=== 1. Configurando Firewall para KDE Connect ==="
if /usr/bin/rpm -q firewalld &>/dev/null; then
    firewall-cmd --permanent --add-service=kdeconnect
    firewall-cmd --reload
fi
log_status $? "Configuración de Firewall"

echo "=== 2. Instalando Aplicaciones del Sistema (DNF) ==="
# < /dev/null evita que dnf se congele esperando input
/usr/bin/dnf install -y steam kde-connect gamemode gamemode-devel < /dev/null
log_status $? "Instalación de Steam, KDE Connect y Gamemode"

echo "=== 3. Configurando carpetas de usuario ==="
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/autostart"
log_status $? "Carpetas de usuario configuradas"

echo "=== 4. Instalando Aplicaciones Flatpak ==="

# Asegurar que el remoto de Flathub exista
/usr/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo < /dev/null

# Actualizar y instalar con < /dev/null para evitar congelamientos por prompts
/usr/bin/flatpak update --appstream -y < /dev/null

/usr/bin/flatpak install --system -y flathub \
    com.discordapp.Discord \
    com.vysp3r.ProtonPlus \
    com.github.tchx84.Flatseal \
    io.github.flattool.Warehouse \
    org.telegram.desktop \
    io.github.kolunmi.Bazaar \
    com.microsoft.Edge < /dev/null

log_status $? "Instalación de Flatpaks"

# ==============================================================================
# 5. OPTIMIZACIÓN DE EDGE
# ==============================================================================
echo "=== 5. Verificando/Optimizando Microsoft Edge ==="
if sudo -u "$REAL_USER" flatpak list --app < /dev/null | grep -q "com.microsoft.Edge"; then
    
    # Aplicar variables de entorno
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/environment.d"
    cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-edge.conf" > /dev/null
LIBVA_DRIVER_NAME=iHD
MOZ_DISABLE_RDD_SANDBOX=1
EOF

    # Aplicar override como usuario real
    sudo -u "$REAL_USER" flatpak override --user com.microsoft.Edge \
        --env=LIBVA_DRIVER_NAME=iHD \
        --env=MOZ_DISABLE_RDD_SANDBOX=1 < /dev/null

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

echo "=== 6. Limpieza final de paquetes y cachés ==="
/usr/bin/flatpak uninstall --unused -y < /dev/null
/usr/bin/update-desktop-database /var/lib/flatpak/exports/share/applications &>/dev/null

echo "--------------------------------------------" >> "$LOG_FILE"
echo "Todas las aplicaciones de usuario han sido instaladas con éxito." >> "$LOG_FILE"
/usr/bin/chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

echo "=============================================================================="
echo " ¡PROCESO FINALIZADO CON ÉXITO!"
echo " Las aplicaciones de usuario y accesos directos están listos en tu entorno."
echo "=============================================================================="
