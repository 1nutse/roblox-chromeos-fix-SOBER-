#!/bin/bash

# ==============================================================================
# MASTER CONFIGURATION (Edit this on GitHub)
# ==============================================================================
CURRENT_VERSION="5.0"

# CHANGELOG TEXT (Keep inside quotes)
CHANGELOG_TEXT="
- Fixed: Github caching issue (Updates appear instantly now).
- Fixed: Version detection logic migrated to Python for 100% accuracy.
- System: Added timestamp to download URL to bypass proxy cache.
- System: Update process is now fully robust.
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
# Note: We use __VERSION_TAG__ as a placeholder to be replaced later.
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# ==============================================================================
# LOCAL CONFIGURATION
# ==============================================================================
# This is replaced automatically by the installer/updater
LOCAL_VERSION="__VERSION_TAG__"

BASE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_FILE="/tmp/sober_update_candidate.sh"
REPO_URL="https://github.com/1nutse/roblox-chromeos-fix-SOBER-"
LAUNCHER_PATH="$HOME/.local/bin/launch-sober-weston.sh"

# ==============================================================================
# PYTHON PARSER & GUI (Handles Version & Changelog)
# ==============================================================================
run_update_logic() {
    local file_path="$1"
    
    python3 -c "
import tkinter as tk
from tkinter import ttk, scrolledtext
import webbrowser
import sys
import re
import os
import time

FILE_PATH = '$file_path'
LOCAL_VER = '$LOCAL_VERSION'
REPO = '$REPO_URL'

def extract_info():
    try:
        with open(FILE_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Extract Version
        v_match = re.search(r'^CURRENT_VERSION\s*=\s*\"(.*?)\"', content, re.MULTILINE)
        remote_ver = v_match.group(1) if v_match else None
        
        # Extract Changelog
        c_match = re.search(r'CHANGELOG_TEXT=\"(.*?)\"', content, re.DOTALL)
        changelog = c_match.group(1).strip() if c_match else 'No changelog found.'
        
        return remote_ver, changelog
    except Exception as e:
        return None, str(e)

def open_url():
    webbrowser.open(REPO)

def on_update():
    print('ACTION_UPDATE')
    root.destroy()

def on_skip():
    print('ACTION_SKIP')
    root.destroy()

# --- LOGIC START ---
remote_ver, changelog = extract_info()

# Only show GUI if version differs and is valid
if remote_ver and remote_ver != LOCAL_VER:
    root = tk.Tk()
    root.title('Roblox Fix - Update')
    root.geometry('550x520')
    root.resizable(False, False)
    style = ttk.Style()
    style.theme_use('clam')
    
    main = ttk.Frame(root, padding='20')
    main.pack(fill='both', expand=True)
    
    ttk.Label(main, text='Update Available!', font=('Helvetica', 16, 'bold')).pack(pady=(0, 5))
    ttk.Label(main, text=f'Current: {LOCAL_VER}  ➜  New: {remote_ver}', font=('Helvetica', 11)).pack(pady=(0, 15))
    
    ttk.Label(main, text='Changelog:', font=('Helvetica', 10, 'bold')).pack(anchor='w')
    
    txt = scrolledtext.ScrolledText(main, height=14, font=('Consolas', 9))
    txt.insert(tk.END, changelog)
    txt.configure(state='disabled')
    txt.pack(fill='both', expand=True, pady=(5, 15))
    
    btns = ttk.Frame(main)
    btns.pack(fill='x')
    
    ttk.Button(btns, text='View Script', command=open_url).pack(side='left')
    ttk.Button(btns, text='Update & Restart', command=on_update).pack(side='right', padx=(5, 0))
    ttk.Button(btns, text='Skip', command=on_skip).pack(side='right')
    
    # Center
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
# Add timestamp to URL to bypass GitHub 5-minute cache
CACHE_BUSTER=$(date +%s)
UPDATE_URL="${BASE_URL}?t=${CACHE_BUSTER}"

if curl -sS -L --max-time 10 "$UPDATE_URL" -o "$TEMP_FILE"; then
    
    # Python handles extraction and comparison now (More reliable than grep)
    RESULT=$(run_update_logic "$TEMP_FILE")
    
    # Clean output (grab last line just in case of GTK warnings)
    ACTION=$(echo "$RESULT" | tail -n 1)
    
    if [ "$ACTION" == "ACTION_UPDATE" ]; then
        echo "[Updater] Installing update..."
        chmod +x "$TEMP_FILE"
        bash "$TEMP_FILE"
        
        echo "[Updater] Restarting application..."
        exec bash "$LAUNCHER_PATH"
    fi
    # If ACTION_NONE or ACTION_SKIP, continue to launch Weston
fi
rm -f "$TEMP_FILE"

# ==============================================================================
# WESTON / SOBER EXECUTION
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

# 5. VERSION STAMPING (Critical)
# This replaces __VERSION_TAG__ with the actual version defined at the top
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
echo "Ready to play."
