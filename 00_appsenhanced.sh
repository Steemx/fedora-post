#!/usr/bin/env bash
# ==============================================================================
# SCRIPT 2: INSTALACIÓN DE APLICACIONES DE USUARIO (BLINDADO + OPTIMIZADO)
# ==============================================================================
set -e
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, ejecuta este script usando sudo: sudo $0"
    exit 1
fi
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")
LOG_FILE="$USER_HOME/fedora_apps_install.log"
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
echo "=== 1. Configurando Firewall para KDE Connect y LocalSend ==="
if /usr/bin/rpm -q firewalld &>/dev/null; then
    firewall-cmd --permanent --add-service=kdeconnect
    firewall-cmd --permanent --add-port=53317/tcp
    firewall-cmd --permanent --add-port=53317/udp
    firewall-cmd --permanent --add-port=53318/tcp
    firewall-cmd --permanent --add-port=53318/udp
    firewall-cmd --reload
fi
log_status $? "Configuración de Firewall"
echo "=== 2. Instalando Aplicaciones del Sistema (DNF) ==="
/usr/bin/dnf install -y steam kde-connect gamemode gamemode-devel mangohud goverlay fuse fuse-libs < /dev/null
log_status $? "Instalación de Steam, KDE Connect, Gamemode y Emuladores"
echo "=== 3. Configurando carpetas de usuario ==="
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/autostart"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.local/bin"
log_status $? "Carpetas de usuario configuradas"
echo "=== 4. Instalando Aplicaciones Flatpak (Pesadas) ==="
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
    io.missioncenter.MissionCenter < /dev/null
log_status $? "Instalación de Flatpaks base"

# ==============================================================================
# 5. SELECCIÓN E INSTALACIÓN DE NAVEGADOR (INTERACTIVO Y OPTIMIZADO)
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
        # 1. Forzar Wayland nativo
        sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/environment.d"
        echo "MOZ_ENABLE_WAYLAND=1" | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-firefox-wayland.conf" > /dev/null

        # 2. Intentar generar el perfil automáticamente
        echo "Inicializando perfil de Firefox para aplicar tweaks..."
        sudo -u "$REAL_USER" timeout 5 firefox --headless >/dev/null 2>&1 || true
        sleep 2

        # Buscar el directorio del perfil (soporta .mozilla y .config/mozilla)
        PROFILE_DIR=$(sudo -u "$REAL_USER" find "$USER_HOME/.mozilla/firefox" "$USER_HOME/.config/mozilla/firefox" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)

        if [ -n "$PROFILE_DIR" ]; then
            echo "Perfil encontrado en: $PROFILE_DIR"
            # Descargar Betterfox Fastfox
            sudo -u "$REAL_USER" curl -s -o "$PROFILE_DIR/user.js" https://raw.githubusercontent.com/yokoffing/Betterfox/main/Fastfox.js
            
            # Agregar tweaks específicos para Celeron N4020 + Intel UHD 605
            cat << 'EOF' | sudo -u "$REAL_USER" tee -a "$PROFILE_DIR/user.js" > /dev/null
// --- Tweaks personalizados para Celeron N4020 + Intel UHD 605 ---
user_pref("dom.ipc.processCount", 2);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("gfx.webrender.all", true);
EOF
            log_status 0 "Tweaks de Firefox aplicados correctamente (Betterfox + VA-API)"
        else
            log_status 1 "No se pudo generar el perfil automáticamente."
        fi

        # 3. Crear script de respaldo por si el perfil cambia de nombre en el futuro
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
        # Agregar repositorio de Microsoft Edge si no existe
        if [ ! -f /etc/yum.repos.d/microsoft-edge.repo ]; then
            /usr/bin/dnf config-manager --add-repo https://packages.microsoft.com/repos/edge/
        fi
        # Importar clave GPG de Microsoft
        rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
        # Instalar Edge
        /usr/bin/dnf install -y microsoft-edge-stable
        log_status $? "Instalación de Edge Nativo (RPM)"

        echo "=== Optimizando Microsoft Edge Nativo (VA-API + Wayland) ==="
        sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/environment.d"
        cat << 'EOF' | sudo -u "$REAL_USER" tee "$USER_HOME/.config/environment.d/99-edge.conf" > /dev/null
LIBVA_DRIVER_NAME=iHD
MOZ_DISABLE_RDD_SANDBOX=1
EOF

        # Configurar flags de rendimiento en el .desktop de Edge nativo
        sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.local/share/applications"
        if [ -f /usr/share/applications/microsoft-edge.desktop ]; then
            cp /usr/share/applications/microsoft-edge.desktop \
               "$USER_HOME/.local/share/applications/"
            sudo -u "$REAL_USER" sed -i 's|^Exec=.*|Exec=/usr/bin/microsoft-edge-stable --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --ozone-platform=wayland %U|' \
               "$USER_HOME/.local/share/applications/microsoft-edge.desktop"
        fi

        # Actualizar base de datos de desktop
        update-desktop-database "$USER_HOME/.local/share/applications" 2>/dev/null || true
        log_status $? "Edge optimizado con VA-API y Wayland"

        # Establecer como predeterminado
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
# 6. Limpieza final de paquetes y cachés
# ==============================================================================
echo "=== 6. Limpieza final de paquetes y cachés ==="
/usr/bin/flatpak uninstall --unused -y < /dev/null
/usr/bin/dnf clean all
/usr/bin/update-desktop-database /var/lib/flatpak/exports/share/applications &>/dev/null

echo "--------------------------------------------" >> "$LOG_FILE"
echo "Todas las aplicaciones de usuario han sido instaladas con éxito." >> "$LOG_FILE"
/usr/bin/chown "$REAL_USER":"$REAL_USER" "$LOG_FILE"

echo "=============================================================================="
echo "🎉 ¡PROCESO FINALIZADO CON ÉXITO!"
if [ "$browser_choice" = "1" ] || [ "$browser_choice" = "3" ]; then
    echo "💡 Si elegiste Firefox, tus tweaks ya están aplicados."
    echo "💡 Si algo falla en el futuro, ejecuta: ~/.local/bin/fix-firefox-tweaks.sh"
fi
echo "=============================================================================="
