#!/bin/bash

# ==============================================================================
# MASTER CONFIGURATION (Edit this on GitHub)
# ==============================================================================
CURRENT_VERSION="1.2"

# CHANGELOG TEXT (Keep inside quotes)
CHANGELOG_TEXT="
- WARNING: this is experimental version.
"
# ==============================================================================

# 1. Dependency Check
echo "[Installer] Checking system dependencies..."
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "[Installer] Installing Weston, Xdotool, and Python-tk..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk python3
fi

# 2. Permissions
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Generate Launcher Script
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# ==============================================================================
# LOCAL CONFIGURATION
# ==============================================================================
LOCAL_VERSION="__VERSION_TAG__"

BASE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix%20EXPERIMENTAL.sh"
TEMP_FILE="/tmp/sober_update_candidate.sh"
REPO_URL="https://github.com/1nutse/roblox-chromeos-fix-SOBER-"
LAUNCHER_PATH="$HOME/.local/bin/launch-sober-weston.sh"

# ==============================================================================
# PYTHON PARSER & WHITE UI (Modern & Smart)
# ==============================================================================
run_update_logic() {
    local file_path="$1"
    
    python3 -c "
import tkinter as tk
from tkinter import ttk, scrolledtext, font
import webbrowser
import sys
import re
import os

FILE_PATH = '$file_path'
LOCAL_VER = '$LOCAL_VERSION'
REPO = '$REPO_URL'

# --- Logic: Extract Info ---
def extract_info():
    try:
        with open(FILE_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        v_match = re.search(r'^CURRENT_VERSION\s*=\s*\"(.*?)\"', content, re.MULTILINE)
        remote_ver = v_match.group(1) if v_match else None
        c_match = re.search(r'CHANGELOG_TEXT=\"(.*?)\"', content, re.DOTALL)
        changelog = c_match.group(1).strip() if c_match else 'No changelog found.'
        return remote_ver, changelog
    except Exception as e:
        return None, str(e)

# --- Logic: Compare Versions ---
def compare_versions(v1, v2):
    # Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
    def normalize(v):
        return [int(x) for x in re.sub(r'(\.0+)*$','', v).split('.')]
    try:
        p1, p2 = normalize(v1), normalize(v2)
        return (p1 > p2) - (p1 < p2) 
    except:
        return 0 # Fallback if versions are weird strings

# --- Actions ---
def open_url():
    webbrowser.open(REPO)

def on_update():
    print('ACTION_UPDATE')
    root.destroy()

def on_skip():
    print('ACTION_SKIP')
    root.destroy()

# --- MAIN ---
remote_ver, changelog = extract_info()

if remote_ver and remote_ver != LOCAL_VER:
    
    # Determine Status (Upgrade or Downgrade)
    comp = compare_versions(remote_ver, LOCAL_VER)
    
    if comp > 0:
        # Upgrade
        status_title = 'New Update Available'
        status_color = '#007AFF' # IOS Blue
        btn_text = 'Update Now'
        ver_text = f'Upgrading: {LOCAL_VER} ➜ {remote_ver}'
    else:
        # Downgrade / Rollback
        status_title = 'Rollback / Downgrade'
        status_color = '#FF9500' # Orange
        btn_text = 'Downgrade Version'
        ver_text = f'Reverting: {LOCAL_VER} ➜ {remote_ver}'

    # --- UI SETUP (Pure White Theme) ---
    root = tk.Tk()
    root.title('Roblox Fix Manager')
    root.geometry('560x540')
    root.configure(bg='white')
    root.resizable(False, False)

    # Styles
    style = ttk.Style()
    style.theme_use('clam')
    
    # Configure White Theme
    style.configure('TFrame', background='white')
    style.configure('TLabel', background='white', foreground='#333333')
    style.configure('Header.TLabel', font=('Helvetica', 18, 'bold'), foreground=status_color)
    style.configure('SubHeader.TLabel', font=('Helvetica', 11), foreground='#666666')
    
    # Rounded/Flat Buttons
    style.configure('Action.TButton', font=('Helvetica', 10, 'bold'), background='white', borderwidth=1)
    style.map('Action.TButton', background=[('active', '#f0f0f0')])

    # Layout
    main = ttk.Frame(root, padding='30')
    main.pack(fill='both', expand=True)

    # Header
    ttk.Label(main, text=status_title, style='Header.TLabel').pack(pady=(0, 5))
    ttk.Label(main, text=ver_text, style='SubHeader.TLabel').pack(pady=(0, 20))

    # Changelog Container
    lbl_change = ttk.Label(main, text='Changelog:', font=('Helvetica', 10, 'bold'))
    lbl_change.pack(anchor='w', pady=(0, 5))

    # Text Area (Styled)
    txt_frame = ttk.Frame(main, padding=1, borderwidth=1, relief='solid') # Thin border container
    txt_frame.pack(fill='both', expand=True, pady=(0, 20))
    
    txt = scrolledtext.ScrolledText(txt_frame, height=10, font=('Consolas', 10), 
                                    bg='#FAFAFA', fg='#333333', relief='flat', padx=10, pady=10)
    txt.insert(tk.END, changelog)
    txt.configure(state='disabled')
    txt.pack(fill='both', expand=True)

    # Buttons
    btns = ttk.Frame(main)
    btns.pack(fill='x')

    # View Code Button
    btn_view = ttk.Button(btns, text='View Source', command=open_url, style='Action.TButton')
    btn_view.pack(side='left')

    # Main Actions
    btn_skip = ttk.Button(btns, text='Skip', command=on_skip, style='Action.TButton')
    btn_skip.pack(side='right')
    
    btn_upd = ttk.Button(btns, text=btn_text, command=on_update, style='Action.TButton')
    btn_upd.pack(side='right', padx=(0, 10))

    # Center Window
    root.update_idletasks()
    w, h = root.winfo_width(), root.winfo_height()
    x = (root.winfo_screenwidth() // 2) - (w // 2)
    y = (root.winfo_screenheight() // 2) - (h // 2)
    root.geometry(f'{w}x{h}+{x}+{y}')

    root.mainloop()
else:
    print('ACTION_NONE')
"
}

# ==============================================================================
# DOWNLOAD & CHECK
# ==============================================================================
CACHE_BUSTER=$(date +%s)
UPDATE_URL="${BASE_URL}?t=${CACHE_BUSTER}"

# Header check to debug
echo "[Launcher] Checking for updates..."

if curl -sS -L --max-time 10 "$UPDATE_URL" -o "$TEMP_FILE"; then
    
    # Run Python Logic
    RESULT=$(run_update_logic "$TEMP_FILE")
    ACTION=$(echo "$RESULT" | tail -n 1) # Grab last line
    
    if [ "$ACTION" == "ACTION_UPDATE" ]; then
        echo "[Updater] Applying changes..."
        chmod +x "$TEMP_FILE"
        bash "$TEMP_FILE"
        
        echo "[Updater] Restarting..."
        exec bash "$LAUNCHER_PATH"
    fi
else
    echo "[Launcher] Offline mode or check failed."
fi
rm -f "$TEMP_FILE"

# ==============================================================================
# WESTON / SOBER EXECUTION (UNCHANGED STABLE CORE)
# ==============================================================================

# Cleanup
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print $1}' | xargs -r kill -9 2>/dev/null

# Env
export SOBER_DISPLAY="wayland-9"
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

CONFIG_DIR="/tmp/weston-sober-config"
mkdir -p "$CONFIG_DIR"
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY"
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY.lock"

# Weston Config
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

# Drivers
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# Mouse Loop
start_infinite_mouse() {
    sleep 2
    read SCREEN_WIDTH SCREEN_HEIGHT <<< $(xdotool getdisplaygeometry)
    while true; do
        eval $(xdotool getmouselocation --shell)
        NEW_X=$X; NEW_Y=$Y; CHANGED=0
        
        [ "$X" -le 0 ] && { NEW_X=$((SCREEN_WIDTH - 2)); CHANGED=1; }
        [ "$X" -ge $((SCREEN_WIDTH - 1)) ] && { NEW_X=1; CHANGED=1; }
        [ "$Y" -le 0 ] && { NEW_Y=$((SCREEN_HEIGHT - 2)); CHANGED=1; }
        [ "$Y" -ge $((SCREEN_HEIGHT - 1)) ] && { NEW_Y=1; CHANGED=1; }
        
        [ "$CHANGED" -eq 1 ] && xdotool mousemove $NEW_X $NEW_Y
        sleep 0.005
    done
}

# Launch
weston --config="$CONFIG_DIR/weston.ini" --socket="$SOBER_DISPLAY" --fullscreen > /tmp/weston.log 2>&1 &
WPID=$!

start_infinite_mouse &
MOUSE_PID=$!

# Wait for socket
for i in {1..50}; do
    [ -S "$XDG_RUNTIME_DIR/$SOBER_DISPLAY" ] && break
    sleep 0.1
done

# Run Game
WAYLAND_DISPLAY="$SOBER_DISPLAY" \
DISPLAY="" \
GDK_BACKEND=wayland \
QT_QPA_PLATFORM=wayland \
SDL_VIDEODRIVER=wayland \
CLUTTER_BACKEND=wayland \
flatpak run org.vinegarhq.Sober

# Exit
kill -TERM $WPID 2>/dev/null
kill $MOUSE_PID 2>/dev/null
rm -rf "$CONFIG_DIR"
EOF

# 5. VERSION STAMPING (Automatic)
sed -i "s/__VERSION_TAG__/$CURRENT_VERSION/" ~/.local/bin/launch-sober-weston.sh

# 6. Finalize
chmod +x ~/.local/bin/launch-sober-weston.sh

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
echo "INSTALLATION COMPLETE (Version $CURRENT_VERSION)"
echo "=========================================="
