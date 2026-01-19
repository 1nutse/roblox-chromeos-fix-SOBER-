#!/bin/bash

# --- CONFIGURACIÓN DE VERSIÓN LOCAL ---
CURRENT_VERSION="2.3"

echo "========================================"
echo "    INSTALANDO SOBER FIX (VER 2.3)      "
echo "========================================"

# 1. VERIFICACIÓN ROBUSTA DE DEPENDENCIAS
# Intentamos importar tkinter directamente. Si falla, instalamos.
echo "[*] Verificando entorno gráfico y librerías..."

NEED_INSTALL=0

if ! command -v weston >/dev/null; then NEED_INSTALL=1; fi
if ! command -v xdotool >/dev/null; then NEED_INSTALL=1; fi
# Comprobamos si Python puede usar Tkinter realmente
if ! python3 -c "import tkinter" >/dev/null 2>&1; then NEED_INSTALL=1; fi

if [ $NEED_INSTALL -eq 1 ]; then
    echo "[!] Faltan dependencias. Instalando (se requerirá contraseña)..."
    sudo apt-get update
    # Instalamos explícitamente python3-tk y python3-pip por si acaso
    sudo apt-get install -y weston xdotool python3-tk python3-dev
else
    echo "[OK] Dependencias correctas."
fi

# 2. Permisos Flatpak
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Directorios
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. GENERAR SCRIPT DE LANZAMIENTO
# Usamos 'EOF' para proteger las variables internas
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# --- CHANGELOG START ---
# Version 2.3:
# - Fixed "Invisible Popup" issue by forcing DISPLAY variable check.
# - Added self-repair for missing Python libraries.
# - Improved UI responsiveness.
# - Cleaned up temporary files more aggressively.
# --- CHANGELOG END ---

MY_VERSION="2.3"

# Rutas y URLs
VERSION_FILE="$HOME/.local/share/sober-fix-version"
# Timestamp para romper caché de GitHub
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh?t=$(date +%s)"
RAW_URL_VIEW="https://github.com/1nutse/roblox-chromeos-fix-SOBER-/blob/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
PYTHON_UI_SCRIPT="/tmp/sober_ui_launcher.py"

# --- UPDATE CHECKER LOGIC ---
check_for_updates() {
    # Asegurar que tenemos DISPLAY (necesario para el popup)
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi

    # Descargar script silenciosamente
    if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_INSTALLER"; then
        
        # Extraer versión remota buscando la cadena exacta
        REMOTE_VER=$(grep -o 'CURRENT_VERSION="[^"]*"' "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        
        # Fallback
        if [ -z "$REMOTE_VER" ]; then
             REMOTE_VER=$(grep "CURRENT_VERSION=" "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        fi

        # Si hay versión remota y es diferente a la local
        if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$MY_VERSION" ]; then
            
            # Extraer Changelog
            CHANGELOG=$(sed -n '/# --- CHANGELOG START ---/,/# --- CHANGELOG END ---/p' "$TEMP_INSTALLER" | sed 's/# //g' | sed 's/--- CHANGELOG START ---//g' | sed 's/--- CHANGELOG END ---//g')
            if [ -z "$CHANGELOG" ]; then CHANGELOG="No details provided in the script."; fi

            # Exportar variables para Python
            export MY_VER="$MY_VERSION"
            export NEW_VER="$REMOTE_VER"
            export CL_TEXT="$CHANGELOG"
            export CODE_URL="$RAW_URL_VIEW"

            # Generar el script Python GUI
            cat > "$PYTHON_UI_SCRIPT" <<'PY_EOF'
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import webbrowser
import sys
import os

# Configuración de seguridad ante fallos
try:
    local_ver = os.environ.get("MY_VER", "Unknown")
    remote_ver = os.environ.get("NEW_VER", "Unknown")
    changelog_content = os.environ.get("CL_TEXT", "No info.")
    code_url = os.environ.get("CODE_URL", "https://github.com")

    def update_now():
        root.destroy()
        sys.exit(10) # 10 = Update

    def play_only():
        root.destroy()
        sys.exit(0) # 0 = Play

    def view_code():
        webbrowser.open(code_url)

    root = tk.Tk()
    root.title("Sober Fix Update Available")

    # Centrar ventana
    w, h = 520, 450
    ws = root.winfo_screenwidth()
    hs = root.winfo_screenheight()
    x = (ws/2) - (w/2)
    y = (hs/2) - (h/2)
    root.geometry('%dx%d+%d+%d' % (w, h, x, y))
    root.resizable(False, False)

    # Estilos
    style = ttk.Style()
    try:
        style.theme_use('clam')
    except:
        pass # Usar default si falla

    # Panel Principal
    main = ttk.Frame(root, padding=15)
    main.pack(fill="both", expand=True)

    # Titulo
    lbl_title = ttk.Label(main, text="New Version Available!", font=("Helvetica", 14, "bold"), foreground="#d9534f")
    lbl_title.pack(pady=(0, 10))

    # Info
    info_frame = ttk.Frame(main)
    info_frame.pack(fill="x", pady=5)
    ttk.Label(info_frame, text=f"Current: {local_ver}", font=("Helvetica", 10)).pack(side="left")
    ttk.Label(info_frame, text=f"New: {remote_ver}", font=("Helvetica", 10, "bold"), foreground="green").pack(side="right")

    # Changelog
    ttk.Label(main, text="Changelog / Changes:", font=("Helvetica", 10, "bold")).pack(anchor="w", pady=(15, 2))
    
    # Text Area
    txt = scrolledtext.ScrolledText(main, height=10, font=("Consolas", 9))
    txt.insert(tk.END, changelog_content)
    txt.configure(state="disabled", bg="#f7f7f7", relief="flat")
    txt.pack(fill="both", expand=True)

    # Botones
    btn_frame = ttk.Frame(main)
    btn_frame.pack(fill="x", pady=(20, 0))

    # Boton Código
    ttk.Button(btn_frame, text="View Script Code", command=view_code).pack(side="left")

    # Botones Acción
    ttk.Button(btn_frame, text="UPDATE NOW", command=update_now).pack(side="right", padx=(10, 0))
    ttk.Button(btn_frame, text="Play Without Updating", command=play_only).pack(side="right")

    # Forzar foco
    root.lift()
    root.attributes('-topmost',True)
    root.after_idle(root.attributes,'-topmost',False)

    root.protocol("WM_DELETE_WINDOW", play_only)
    root.mainloop()

except Exception as e:
    # Si falla la UI gráfica, imprimimos error y salimos con 0 (Jugar) para no bloquear
    print(f"UI Error: {e}")
    sys.exit(0)
PY_EOF

            # Ejecutar Python y capturar código de salida
            python3 "$PYTHON_UI_SCRIPT"
            EXIT_CODE=$?
            rm -f "$PYTHON_UI_SCRIPT"

            # Decisión
            if [ $EXIT_CODE -eq 10 ]; then
                echo "User chose update. Running installer..."
                chmod +x "$TEMP_INSTALLER"
                bash "$TEMP_INSTALLER"
                exit 0 # Detenemos este script para que el nuevo tome el control
            fi
        fi
    fi
    # Limpiar
    rm -f "$TEMP_INSTALLER"
}

# --- 1. COMPROBAR ACTUALIZACIONES ANTES DE NADA ---
check_for_updates

# =========================================================================
#                   INICIO DEL JUEGO (WESTON + SOBER)
# =========================================================================

# --- CLEANUP ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print $1}' | xargs -r kill -9 2>/dev/null

# --- VARS ---
export SOBER_DISPLAY="wayland-9"
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

CONFIG_DIR="/tmp/weston-sober-config"
mkdir -p "$CONFIG_DIR"
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY"
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY.lock"

# --- WESTON CONFIG ---
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

# --- DRIVERS ---
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# --- MOUSE FIX ---
start_infinite_mouse() {
    sleep 2
    read SCREEN_WIDTH SCREEN_HEIGHT <<< $(xdotool getdisplaygeometry)
    while true; do
        eval $(xdotool getmouselocation --shell)
        NEW_X=$X; NEW_Y=$Y; CHANGED=0
        
        if [ "$X" -le 0 ]; then NEW_X=$((SCREEN_WIDTH - 2)); CHANGED=1;
        elif [ "$X" -ge $((SCREEN_WIDTH - 1)) ]; then NEW_X=1; CHANGED=1; fi
        
        if [ "$Y" -le 0 ]; then NEW_Y=$((SCREEN_HEIGHT - 2)); CHANGED=1;
        elif [ "$Y" -ge $((SCREEN_HEIGHT - 1)) ]; then NEW_Y=1; CHANGED=1; fi
        
        if [ "$CHANGED" -eq 1 ]; then xdotool mousemove $NEW_X $NEW_Y; fi
        sleep 0.005
    done
}

# --- LAUNCH WESTON ---
weston --config="$CONFIG_DIR/weston.ini" --socket="$SOBER_DISPLAY" --fullscreen > /tmp/weston-sober.log 2>&1 &
WPID=$!

start_infinite_mouse &
MOUSE_PID=$!

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

# --- EXIT ---
kill -TERM $WPID 2>/dev/null
kill $MOUSE_PID 2>/dev/null
rm -rf "$CONFIG_DIR"
EOF

# 5. Permisos
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

# 7. Guardar versión
echo "$CURRENT_VERSION" > ~/.local/share/sober-fix-version

echo ""
echo "=========================================="
echo " INSTALACION EXITOSA (Ver $CURRENT_VERSION)"
echo "=========================================="
echo "Prueba iniciar 'Roblox (Sober Fix)' ahora."
echo "La interfaz de actualización debería aparecer correctamente."
