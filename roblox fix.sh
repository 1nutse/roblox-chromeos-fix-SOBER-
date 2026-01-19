#!/bin/bash

# ==============================================================================
# CONFIGURATION & CHANGELOG
# ==============================================================================
CURRENT_VERSION="3.0"

# CHANGELOG TEXT (Keep the structure exactly like this)
CHANGELOG_TEXT="
- Fixed: Update loop bugs completely resolved.
- Fixed: Changelog is now read directly by Python (100% reliable).
- Fixed: Auto-restart now uses absolute path to prevent closure.
- Feature: Added failsafe if changelog cannot be read.
- System: Weston and Mouse fixes maintained strictly.
"
# ==============================================================================

# 1. Install Dependencies
echo "Checking system dependencies..."
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing Weston, Xdotool, and Python-tk..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk python3
fi

# 2. Flatpak Overrides
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Generate the robust Launcher
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# ==============================================================================
# 1. SETUP VARIABLES
# ==============================================================================
# NOTA: El instalador reemplazará esta línea con la versión real
CURRENT_VERSION="3.0" 

UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_FILE="/tmp/sober_update_candidate.sh"
REPO_URL="https://github.com/1nutse/roblox-chromeos-fix-SOBER-"
LAUNCHER_PATH="$HOME/.local/bin/launch-sober-weston.sh"

# ==============================================================================
# 2. PYTHON GUI UPDATER (Self-Contained)
# ==============================================================================
# This function creates a python script on the fly that reads the downloaded file
run_update_gui() {
    local remote_ver="$1"
    local file_path="$2"
    
    python3 -c "
import tkinter as tk
from tkinter import ttk, scrolledtext
import webbrowser
import sys
import re
import os

# --- Configuration ---
FILE_PATH = '$file_path'
REMOTE_VER = '$remote_ver'
LOCAL_VER = '$CURRENT_VERSION'
REPO = '$REPO_URL'

def get_changelog():
    try:
        with open(FILE_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        # Robust Regex to find the variable CHANGELOG_TEXT=\"...\"
        match = re.search(r'CHANGELOG_TEXT=\"(.*?)\"', content, re.DOTALL)
        if match:
            return match.group(1).strip()
        return 'Changelog not found in the remote file.'
    except Exception as e:
        return f'Error reading changelog: {str(e)}'

def open_url():
    webbrowser.open(REPO)

def on_update():
    print('UPDATE')
    root.destroy()

def on_skip():
    print('SKIP')
    root.destroy()

# --- GUI Setup ---
root = tk.Tk()
root.title('Roblox Fix - Update')
root.geometry('550x500')
root.resizable(False, False)

style = ttk.Style()
style.theme_use('clam')

main_frame = ttk.Frame(root, padding='20')
main_frame.pack(fill='both', expand=True)

# Header
ttk.Label(main_frame, text='New Update Available', font=('Helvetica', 16, 'bold')).pack(pady=(0, 5))
ttk.Label(main_frame, text=f'Version: {LOCAL_VER}  ➜  {REMOTE_VER}', font=('Helvetica', 11)).pack(pady=(0, 15))

# Changelog
ttk.Label(main_frame, text='What\'s New:', font=('Helvetica', 10, 'bold')).pack(anchor='w')

txt = scrolledtext.ScrolledText(main_frame, height=14, font=('Consolas', 9))
txt.insert(tk.END, get_changelog())
txt.configure(state='disabled')
txt.pack(fill='both', expand=True, pady=(5, 15))

# Buttons
btn_frame = ttk.Frame(main_frame)
btn_frame.pack(fill='x')

ttk.Button(btn_frame, text='View Script', command=open_url).pack(side='left')
ttk.Button(btn_frame, text='Update & Restart', command=on_update).pack(side='right', padx=(5, 0))
ttk.Button(btn_frame, text='Skip Update', command=on_skip).pack(side='right')

# Center Window
root.update_idletasks()
w = root.winfo_width()
h = root.winfo_height()
x = (root.winfo_screenwidth() // 2) - (w // 2)
y = (root.winfo_screenheight() // 2) - (h // 2)
root.geometry(f'{w}x{h}+{x}+{y}')

root.mainloop()
"
}

# ==============================================================================
# 3. UPDATE CHECK LOGIC
# ==============================================================================
# Download silently
if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_FILE"; then
    
    # Extract version from the first 20 lines (avoids reading the whole file)
    REMOTE_VER=$(head -n 20 "$TEMP_FILE" | grep '^CURRENT_VERSION=' | head -n 1 | cut -d'"' -f2)
    
    # Check if update is needed
    if [ "$REMOTE_VER" != "$CURRENT_VERSION" ] && [ -n "$REMOTE_VER" ]; then
        
        # Show Python Popup (It reads the file directly)
        USER_ACTION=$(run_update_gui "$REMOTE_VER" "$TEMP_FILE")
        
        if [ "$USER_ACTION" == "UPDATE" ]; then
            echo "Applying update..."
            chmod +x "$TEMP_FILE"
            
            # Execute the downloaded script to install itself
            bash "$TEMP_FILE"
            
            # CLEAN RESTART
            echo "Restarting application..."
            exec bash "$LAUNCHER_PATH"
        fi
    fi
fi
rm -f "$TEMP_FILE"

# ==============================================================================
# 4. WESTON & SOBER EXECUTION (STABLE)
# ==============================================================================

# Cleanup
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print $1}' | xargs -r kill -9 2>/dev/null

# Environment
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

# Wait for Wayland socket
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

# Cleanup on Exit
kill -TERM $WPID 2>/dev/null
kill $MOUSE_PID 2>/dev/null
rm -rf "$CONFIG_DIR"
EOF

# 5. Inject current version correctly into the generated script
sed -i "s/^CURRENT_VERSION=\"3.0\"/CURRENT_VERSION=\"$CURRENT_VERSION\"/" ~/.local/bin/launch-sober-weston.sh

# 6. Set Permissions
chmod +x ~/.local/bin/launch-sober-weston.sh

# 7. Desktop Entry
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
echo "Launch 'Roblox (Sober Fix)' from your menu."
