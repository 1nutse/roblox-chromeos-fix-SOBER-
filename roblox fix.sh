#!/bin/bash

# --- CONFIGURACIÓN DE VERSIÓN LOCAL (INSTALADOR) ---
CURRENT_VERSION="2.1"

# 1. Verificar e Instalar dependencias (Weston, Xdotool, Python3-Tk)
echo "Verifying dependencies..."
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing required packages (Weston, Xdotool, Python3-Tk)..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk
fi

# 2. Permisos de Flatpak
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Crear directorios
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. CREAR EL SCRIPT DE LANZAMIENTO OPTIMIZADO
# Usamos 'EOF' entre comillas para evitar que se expandan las variables aquí.
# Las variables se expandirán cuando el usuario EJECUTE el script resultante.
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# --- CHANGELOG START ---
# Version 2.1:
# - Fixed bug where update popup would not appear.
# - Added anti-cache mechanism for GitHub updates.
# - Improved Python script generation logic.
# --- CHANGELOG END ---

# VERSION ACTUAL DE ESTE SCRIPT
MY_VERSION="2.1"

# CONFIGURACION
VERSION_FILE="$HOME/.local/share/sober-fix-version"
# Añadimos un timestamp para evitar cache de Github
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh?t=$(date +%s)"
RAW_URL_NO_PARAM="https://github.com/1nutse/roblox-chromeos-fix-SOBER-/blob/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
PYTHON_UI_SCRIPT="/tmp/sober_update_ui.py"

# --- UPDATE CHECKER FUNCTION ---
check_for_updates() {
    echo "Checking for updates..."
    
    # Descargar el script remoto (con timeout de 5s)
    if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_INSTALLER"; then
        
        # 1. Extraer versión remota (Buscamos la linea exacta CURRENT_VERSION="X")
        # Usamos grep flexible para encontrar la variable donde sea que esté en el archivo
        REMOTE_VER=$(grep -o 'CURRENT_VERSION="[^"]*"' "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        
        # Si falló el grep anterior, intentamos búsqueda simple
        if [ -z "$REMOTE_VER" ]; then
             REMOTE_VER=$(grep "CURRENT_VERSION=" "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        fi

        echo "Local Version: $MY_VERSION"
        echo "Remote Version: $REMOTE_VER"

        # 2. Comparar versiones
        if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$MY_VERSION" ]; then
            echo "Update found! Preparing GUI..."
            
            # 3. Extraer Changelog (sed extrae texto entre los marcadores)
            CHANGELOG=$(sed -n '/# --- CHANGELOG START ---/,/# --- CHANGELOG END ---/p' "$TEMP_INSTALLER" | sed 's/# //g' | sed 's/--- CHANGELOG START ---//g' | sed 's/--- CHANGELOG END ---//g')
            
            # Si el changelog está vacío, poner mensaje por defecto
            if [ -z "$CHANGELOG" ]; then CHANGELOG="No changelog details available."; fi

            # 4. Crear script de Python temporal (evita problemas de comillas en bash)
            cat > "$PYTHON_UI_SCRIPT" <<PYEOF
import tkinter as tk
from tkinter import messagebox, scrolledtext
import webbrowser
import sys

# Datos inyectados
local_ver = "$MY_VERSION"
remote_ver = "$REMOTE_VER"
changelog_text = """$CHANGELOG"""
script_url = "$RAW_URL_NO_PARAM"

def on_update():
    root.destroy()
    sys.exit(10) # Código 10 = ACTUALIZAR

def on_skip():
    root.destroy()
    sys.exit(0) # Código 0 = JUGAR SIN ACTUALIZAR

def on_view_code():
    webbrowser.open(script_url)

# Configuración Ventana
root = tk.Tk()
root.title("Sober Fix - Update Available")
root.geometry("520x450")
root.resizable(False, False)

# Main Frame
main_frame = tk.Frame(root, padx=20, pady=20)
main_frame.pack(expand=True, fill="both")

# Título
tk.Label(main_frame, text="Update Available!", font=("Helvetica", 16, "bold"), fg="#d32f2f").pack(pady=(0, 10))

# Info Versiones
info_frame = tk.Frame(main_frame, relief="groove", borderwidth=2, padx=10, pady=5)
info_frame.pack(fill="x", pady=5)
tk.Label(info_frame, text=f"Your Version: {local_ver}", font=("Helvetica", 10)).pack(side="left")
tk.Label(info_frame, text=f"New Version: {remote_ver}", font=("Helvetica", 10, "bold"), fg="green").pack(side="right")

# Changelog
tk.Label(main_frame, text="What's New:", font=("Helvetica", 10, "bold"), anchor="w").pack(fill="x", pady=(15, 5))

txt_area = scrolledtext.ScrolledText(main_frame, height=10, font=("Consolas", 9), bg="#f5f5f5")
txt_area.insert(tk.END, changelog_text)
txt_area.configure(state="disabled") # Solo lectura
txt_area.pack(fill="both", expand=True)

# Botones
btn_frame = tk.Frame(main_frame, pady=20)
btn_frame.pack(fill="x")

# Boton Ver Codigo (Izquierda)
tk.Button(btn_frame, text="View Code", command=on_view_code).pack(side="left")

# Botones Acción (Derecha)
tk.Button(btn_frame, text="UPDATE NOW", bg="#007bff", fg="white", font=("Helvetica", 10, "bold"), padx=10, command=on_update).pack(side="right", marginLeft=10)
tk.Button(btn_frame, text="Play without updating", command=on_skip).pack(side="right", padx=10)

# Manejar cierre de ventana (X) como Skip
root.protocol("WM_DELETE_WINDOW", on_skip)

root.mainloop()
PYEOF

            # 5. Ejecutar Python
            python3 "$PYTHON_UI_SCRIPT"
            EXIT_CODE=$?
            
            # Limpiar script python
            rm -f "$PYTHON_UI_SCRIPT"

            # 6. Acción según el usuario
            if [ $EXIT_CODE -eq 10 ]; then
                echo "Starting update process..."
                chmod +x "$TEMP_INSTALLER"
                bash "$TEMP_INSTALLER"
                exit 0 # Salir de este script, el nuevo script tomará el control
            else
                echo "Update skipped by user."
            fi
        fi
    else
        echo "Could not check for updates (No internet or GitHub down). Proceeding..."
    fi
    # Limpiar instalador temp si no se usó
    rm -f "$TEMP_INSTALLER"
}

# EJECUTAR CHEQUEO DE UPDATE ANTES DE NADA
check_for_updates

# =========================================================================
#                   AQUÍ COMIENZA EL LANZAMIENTO DEL JUEGO
# =========================================================================

# --- CLEANUP PREVIOUS INSTANCES ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print $1}' | xargs -r kill -9 2>/dev/null

# --- ENVIRONMENT CONFIGURATION ---
export SOBER_DISPLAY="wayland-9"
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

CONFIG_DIR="/tmp/weston-sober-config"
mkdir -p "$CONFIG_DIR"
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY"
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY.lock"

# --- WESTON CONFIGURATION ---
cat > "$CONFIG_DIR/weston.ini" <<INNER_EOF
[core]
backend=x11-backend.so
shell=kiosk-shell.so
idle-time=0

[shell]
locking=false

[libinput]
accel-profile=flat

[output]
name=X1
mode=current
INNER_EOF

# --- STABILITY VARIABLES (X11 + Drivers) ---
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# --- INFINITE MOUSE LOOP ---
start_infinite_mouse() {
    sleep 2
    read SCREEN_WIDTH SCREEN_HEIGHT <<< $(xdotool getdisplaygeometry)
    
    while true; do
        eval $(xdotool getmouselocation --shell)
        NEW_X=$X
        NEW_Y=$Y
        CHANGED=0
        
        if [ "$X" -le 0 ]; then NEW_X=$((SCREEN_WIDTH - 2)); CHANGED=1;
        elif [ "$X" -ge $((SCREEN_WIDTH - 1)) ]; then NEW_X=1; CHANGED=1; fi
        
        if [ "$Y" -le 0 ]; then NEW_Y=$((SCREEN_HEIGHT - 2)); CHANGED=1;
        elif [ "$Y" -ge $((SCREEN_HEIGHT - 1)) ]; then NEW_Y=1; CHANGED=1; fi
        
        if [ "$CHANGED" -eq 1 ]; then xdotool mousemove $NEW_X $NEW_Y; fi
        sleep 0.005
    done
}

# --- START WESTON ---
weston --config="$CONFIG_DIR/weston.ini" --socket="$SOBER_DISPLAY" --fullscreen > /tmp/weston-sober.log 2>&1 &
WPID=$!

start_infinite_mouse &
MOUSE_PID=$!

# Wait for socket
for i in {1..50}; do
    if [ -S "$XDG_RUNTIME_DIR/$SOBER_DISPLAY" ]; then break; fi
    sleep 0.1
done

# --- LAUNCH SOBER ---
WAYLAND_DISPLAY="$SOBER_DISPLAY" \
DISPLAY="" \
GDK_BACKEND=wayland \
QT_QPA_PLATFORM=wayland \
SDL_VIDEODRIVER=wayland \
CLUTTER_BACKEND=wayland \
flatpak run org.vinegarhq.Sober

# --- EXIT CLEANUP ---
kill -TERM $WPID 2>/dev/null
kill $MOUSE_PID 2>/dev/null
rm -rf "$CONFIG_DIR"
EOF

# 5. Set execution permissions
chmod +x ~/.local/bin/launch-sober-weston.sh

# 6. Create Desktop Entry
cat > ~/.local/share/applications/sober-fix.desktop <<EOF
[Desktop Entry]
Name=Roblox (Sober Fix)
Comment=Play Roblox via Weston (Stable Version)
Exec=$HOME/.local/bin/launch-sober-weston.sh
Icon=org.vinegarhq.Sober
Terminal=false
Type=Application
Categories=Game;
EOF

chmod +x ~/.local/share/applications/sober-fix.desktop

# 7. Write version file
echo "$CURRENT_VERSION" > ~/.local/share/sober-fix-version

echo "=========================================="
echo "INSTALACIÓN COMPLETADA (Versión $CURRENT_VERSION)"
echo "=========================================="
echo "Se ha arreglado la detección de actualizaciones."
echo "Ahora, si subes la version en GitHub, el popup aparecerá correctamente."
echo "Puedes iniciar el juego desde el menú de aplicaciones."
