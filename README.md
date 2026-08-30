Script personal para mi laptop celeron n4020.


Instalacion directa


curl -sSL https://raw.githubusercontent.com/Steemx/fedora-postinstall/main/00_gnome.sh | sudo bash




########### Para youtube terminal############

## YouTube Terminal Client

Cliente ligero de YouTube en terminal con soporte para cuenta Premium, playlists y modo audio-only.

**Instalación:**
```bash
curl -o ~/.local/bin/yt-terminal https://raw.githubusercontent.com/Steemx/fedora-post/main/yt-terminal
chmod +x ~/.local/bin/yt-terminal
```
echo "alias yt='python3 ~/.local/bin/yt-terminal'" >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish


**Configuración inicial:**
1. Ejecuta `yt`
2. Configura tu usuario de YouTube
3. Exporta las cookies desde Edge (ver instrucciones en el programa)

**Uso:** Simplemente ejecuta `yt`




