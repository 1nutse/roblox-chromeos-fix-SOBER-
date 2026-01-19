#!/bin/bash

# ==============================================================================
# CONFIGURATION & CHANGELOG
# ==============================================================================
# Esta variable define la versión.
CURRENT_VERSION="2.1"

# NOTA PARA EL DESARROLLADOR: Mantén este formato exacto (comillas en líneas separadas o pegadas)
# para que el extractor funcione correctamente.
CHANGELOG_TEXT="
- Fixed: Application now restarts automatically after update (no manual reopen needed).
- Fixed: Changelog text extraction logic improved (now visible in popup).
- Improved: Python popup now receives text via environment variables for safety.
- Stability: Weston and Mouse loop logic remains untouched.
"
# ==============================================================================

# 1. Instalar dependencias necesarias (Weston, Xdotool, Python3-tk)
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing dependencies..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk python3
fi

# 2. Permisos Flatpak
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Crear directorios
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Crear el script de lanzamiento optimizado
cat > ~/.local/bin/launch-sober-weston.sh <<EOF
#!/bin/bash

# ==============================================================================
# VARIABLES
# ==============================================================================
LOCAL_VERSION="$CURRENT_VERSION"
# URL del script "raw" en GitHub
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
REPO_URL="https://github.com/1nutse/roblox-chromeos-fix-SOBER-"

# ==============================================================================
# PYTHON GUI UPDATER
# ==============================================================================
show_update_popup() {
    local remote_ver="\$1"
    
    # El changelog ya está exportado en la variable de entorno REMOTE_CHANGELOG
    # Esto evita errores de sintaxis en bash al pasarlo como argumento.
    
    python3 -c "
import tkinter as tk
from tkinter import ttk, scrolledtext
import webbrowser
import sys
import os

def open_url():
    webbrowser.open('$REPO_URL')

def on_update():
    print('UPDATE')
    root.destroy()

def on_skip():
    print('SKIP')
    root.destroy()

root = tk.Tk()
root.title('Roblox Fix - Update Available')
root.geometry('520x480')
root.resizable(False, False)

style = ttk.Style()
style.theme_use('clam')

main_frame = ttk.Frame(root, padding='20')
main_frame.pack(fill='both', expand=True)

# Encabezado
ttk.Label(main_frame, text='New Version Available!', font=('Helvetica', 16, 'bold')).pack(pady=(0, 5))
ttk.Label(main_frame, text=f'Current: $LOCAL_VERSION  ➜  New: {remote_ver}', font=('Helvetica', 11)).pack(pady=(0, 15))

# Changelog
ttk.Label(main_frame, text='Changelog / What\'s New:', font=('Helvetica', 10, 'bold')).pack(anchor='w')

# Obtener texto desde variable de entorno
changelog_text = os.environ.get('REMOTE_CHANGELOG', 'No changelog info available.')

txt = scrolledtext.ScrolledText(main_frame, height=12, font=('Consolas', 9))
txt.insert(tk.END, changelog_text.strip())
txt.configure(state='disabled') # Solo lectura
txt.pack(fill='both', expand=True, pady=(5, 15))

# Botones
btn_frame = ttk.Frame(main_frame)
btn_frame.pack(fill='x')

ttk.Button(btn_frame, text='View Code (GitHub)', command=open_url).pack(side='left')
ttk.Button(btn_frame, text='Update Now', command=on_update).pack(side='right', padx=(5, 0))
ttk.Button(btn_frame, text='Skip & Play', command=on_skip).pack(side='right')

# Centrar ventana
root.eval('tk::PlaceWindow . center')
root.mainloop()
"
}

# ==============================================================================
# CHECK FOR UPDATES
# ==============================================================================
# Descargar el instalador silenciosamente para comprobar versión
if curl -sS --max-time 5 "\$UPDATE_URL" -o "\$TEMP_INSTALLER"; then
    
    # 1. Extraer Versión
    REMOTE_VER=\$(grep '^CURRENT_VERSION=' "\$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
    
    # 2. Extraer Changelog (Método Robustecido con SED)
    # Busca desde CHANGELOG_TEXT=" hasta la siguiente comilla final, y limpia las comillas.
    RAW_CHANGELOG=\$(sed -n '/^CHANGELOG_TEXT="/,/"$/p' "\$TEMP_INSTALLER" | sed 's/^CHANGELOG_TEXT="//;s/"$//')
    
    # Si las versiones son diferentes y existe una versión remota válida
    if [ "\$REMOTE_VER" != "\$LOCAL_VERSION" ] && [ -n "\$REMOTE_VER" ]; then
        
        # Exportamos para que Python lo lea sin errores de comillas
        export REMOTE_CHANGELOG="\$RAW_CHANGELOG"
        
        # Ejecutar Popup
        USER_CHOICE=\$(show_update_popup "\$REMOTE_VER")
        
        if [ "\$USER_CHOICE" == "UPDATE" ]; then
            echo "Updating system..."
            chmod +x "\$TEMP_INSTALLER"
            
            # Ejecutar el instalador descargado
            bash "\$TEMP_INSTALLER"
            
            # === CORRECCIÓN IMPORTANTE ===
            # Reemplazar el proceso actual con el script recién actualizado.
            # Esto reinicia la aplicación automáticamente con el nuevo código.
            exec "\$0"
            
        elif [ "\$USER_CHOICE" == "SKIP" ]; then
            echo "Update skipped by user. Starting outdated version..."
        else
            # Si cierra la ventana con la X, asumimos Skip
            echo "Window closed. Starting..."
        fi
    fi
fi
rm -f "\$TEMP_INSTALLER"

# ==============================================================================
# WESTON & SOBER (LÓGICA INTACTA)
# ==============================================================================

# --- CLEANUP ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print \$1}' | xargs -r kill -9 2>/dev/null

# --- ENV VARS ---
export SOBER_DISPLAY="wayland-9"
if [ -z "\$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
fi

CONFIG_DIR="/tmp/weston-sober-config"
mkdir -p "\$CONFIG_DIR"
rm -f "\$XDG_RUNTIME_DIR/\$SOBER_DISPLAY"
rm -f "\$XDG_RUNTIME_DIR/\$SOBER_DISPLAY.lock"

# --- WESTON INI ---
cat > "\$CONFIG_DIR/weston.ini" <<INNER_EOF
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

# --- DRIVER FIXES ---
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# --- MOUSE LOOP ---
start_infinite_mouse() {
    sleep 2
    read SCREEN_WIDTH SCREEN_HEIGHT <<< \$(xdotool getdisplaygeometry)
    
    while true; do
        eval \$(xdotool getmouselocation --shell)
        NEW_X=\$X
        NEW_Y=\$Y
        CHANGED=0
        
        if [ "\$X" -le 0 ]; then
            NEW_X=\$((SCREEN_WIDTH - 2))
            CHANGED=1
        elif [ "\$X" -ge \$((SCREEN_WIDTH - 1)) ]; then
            NEW_X=1
            CHANGED=1
        fi
        
        if [ "\$Y" -le 0 ]; then
            NEW_Y=\$((SCREEN_HEIGHT - 2))
            CHANGED=1
        elif [ "\$Y" -ge \$((SCREEN_HEIGHT - 1)) ]; then
            NEW_Y=1
            CHANGED=1
        fi
        
        if [ "\$CHANGED" -eq 1 ]; then
            xdotool mousemove \$NEW_X \$NEW_Y
        fi
        sleep 0.005
    done
}

# --- LAUNCH WESTON ---
weston --config="\$CONFIG_DIR/weston.ini" --socket="\$SOBER_DISPLAY" --fullscreen > /tmp/weston-sober.log 2>&1 &
WPID=\$!

start_infinite_mouse &
MOUSE_PID=\$!

# Wait for socket
for i in {1..50}; do
    if [ -S "\$XDG_RUNTIME_DIR/\$SOBER_DISPLAY" ]; then
        break
    fi
    sleep 0.1
done

# --- LAUNCH SOBER ---
WAYLAND_DISPLAY="\$SOBER_DISPLAY" \
DISPLAY="" \
GDK_BACKEND=wayland \
QT_QPA_PLATFORM=wayland \
SDL_VIDEODRIVER=wayland \
CLUTTER_BACKEND=wayland \
flatpak run org.vinegarhq.Sober

# --- EXIT ---
kill -TERM \$WPID 2>/dev/null
kill \$MOUSE_PID 2>/dev/null
rm -rf "\$CONFIG_DIR"
EOF

# 5. Permisos de ejecución
chmod +x ~/.local/bin/launch-sober-weston.sh

# 6. Desktop Entry
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

echo "=========================================="
echo "INSTALACIÓN COMPLETADA (Versión $CURRENT_VERSION)"
echo "=========================================="
echo "Changelog extractor fixed."
echo "Auto-restart after update implemented."
echo "Puede cerrar esta ventana e iniciar desde el menú."
