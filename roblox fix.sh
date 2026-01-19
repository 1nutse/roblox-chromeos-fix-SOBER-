#!/bin/bash

# --- CONFIGURACIÓN DE VERSIÓN LOCAL ---
CURRENT_VERSION="2.3"

# 1. Check dependencies (Weston, Xdotool, Python3-Tk)
# We need python3-tk for the pretty popup
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing required packages (Weston, Xdotool, Python3-Tk)..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk
fi

# 2. Permissions
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. GENERATE THE LAUNCH SCRIPT
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# --- CHANGELOG START ---
# Version 2.2:
# - Completely redesigned Update UI using Python TTK.
# - Fixed character encoding issues (weird symbols).
# - Removed redundant buttons.
# - Improved "View Code" functionality.
# - Interface is now cleaner and fully in English.
# --- CHANGELOG END ---

MY_VERSION="2.2"

# PATHS & URLS
VERSION_FILE="$HOME/.local/share/sober-fix-version"
# Anti-cache timestamp added to URL
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh?t=$(date +%s)"
RAW_URL_VIEW="https://github.com/1nutse/roblox-chromeos-fix-SOBER-/blob/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
PYTHON_UI_SCRIPT="/tmp/sober_ui.py"

# --- UPDATE CHECKER LOGIC ---
check_for_updates() {
    # Download script silently with timeout
    if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_INSTALLER"; then
        
        # Extract Remote Version
        # We look for CURRENT_VERSION="X.X" anywhere in the file
        REMOTE_VER=$(grep -o 'CURRENT_VERSION="[^"]*"' "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        
        # Fallback if grep fails
        if [ -z "$REMOTE_VER" ]; then
             REMOTE_VER=$(grep "CURRENT_VERSION=" "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        fi

        # Compare Versions
        if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$MY_VERSION" ]; then
            
            # Extract Changelog cleanly
            CHANGELOG=$(sed -n '/# --- CHANGELOG START ---/,/# --- CHANGELOG END ---/p' "$TEMP_INSTALLER" | sed 's/# //g' | sed 's/--- CHANGELOG START ---//g' | sed 's/--- CHANGELOG END ---//g')
            if [ -z "$CHANGELOG" ]; then CHANGELOG="No details provided."; fi

            # Export variables to be read by Python (Safe way to pass multi-line text)
            export MY_VER="$MY_VERSION"
            export NEW_VER="$REMOTE_VER"
            export CL_TEXT="$CHANGELOG"
            export CODE_URL="$RAW_URL_VIEW"

            # Generate Python GUI Script
            cat > "$PYTHON_UI_SCRIPT" <<'PY_EOF'
import tkinter as tk
from tkinter import ttk, scrolledtext
import webbrowser
import sys
import os

# Read Environment Variables
local_ver = os.environ.get("MY_VER", "Unknown")
remote_ver = os.environ.get("NEW_VER", "Unknown")
changelog_content = os.environ.get("CL_TEXT", "No info.")
code_url = os.environ.get("CODE_URL", "https://github.com")

def update_now():
    root.destroy()
    sys.exit(10) # Exit 10 = Update

def play_only():
    root.destroy()
    sys.exit(0) # Exit 0 = Play

def view_code():
    webbrowser.open(code_url)

# Setup Window
root = tk.Tk()
root.title("Sober Fix Update")

# Center the window
window_width = 500
window_height = 420
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()
x_c = int((screen_width/2) - (window_width/2))
y_c = int((screen_height/2) - (window_height/2))
root.geometry(f"{window_width}x{window_height}+{x_c}+{y_c}")
root.resizable(False, False)

# Style configuration
style = ttk.Style()
style.theme_use('clam') # 'clam' usually looks clean on Linux
style.configure("TLabel", font=("Helvetica", 11))
style.configure("TButton", font=("Helvetica", 10))
style.configure("Header.TLabel", font=("Helvetica", 14, "bold"), foreground="#333")
style.configure("Ver.TLabel", font=("Helvetica", 10), foreground="#555")

# Main Container with Padding
main_frame = ttk.Frame(root, padding="20")
main_frame.pack(fill="both", expand=True)

# Header
header = ttk.Label(main_frame, text="Update Available", style="Header.TLabel")
header.pack(pady=(0, 10))

# Version Info Grid
info_frame = ttk.Frame(main_frame)
info_frame.pack(fill="x", pady=5)

ttk.Label(info_frame, text=f"Current: {local_ver}", style="Ver.TLabel").pack(side="left")
ttk.Label(info_frame, text=f"New: {remote_ver}", style="Ver.TLabel", foreground="green").pack(side="right")

# Changelog Area
ttk.Label(main_frame, text="Changelog:", font=("Helvetica", 10, "bold")).pack(anchor="w", pady=(15, 5))

text_area = scrolledtext.ScrolledText(main_frame, height=10, font=("Consolas", 10), relief="flat", bg="#f4f4f4")
text_area.insert(tk.END, changelog_content)
text_area.configure(state="disabled") # Read-only
text_area.pack(fill="both", expand=True)

# Buttons Area
btn_frame = ttk.Frame(main_frame)
btn_frame.pack(fill="x", pady=(20, 0))

# Left Button
btn_view = ttk.Button(btn_frame, text="View Code", command=view_code)
btn_view.pack(side="left")

# Right Buttons
btn_update = ttk.Button(btn_frame, text="Update Now", command=update_now)
btn_update.pack(side="right", padx=(5, 0))

btn_play = ttk.Button(btn_frame, text="Play Only", command=play_only)
btn_play.pack(side="right")

# Handle window close (X)
root.protocol("WM_DELETE_WINDOW", play_only)

root.mainloop()
PY_EOF

            # Run Python
            python3 "$PYTHON_UI_SCRIPT"
            EXIT_CODE=$?
            rm -f "$PYTHON_UI_SCRIPT"

            # Handle Result
            if [ $EXIT_CODE -eq 10 ]; then
                echo "User selected Update."
                chmod +x "$TEMP_INSTALLER"
                bash "$TEMP_INSTALLER"
                exit 0 # Stop current script, new one takes over
            fi
        fi
    fi
    rm -f "$TEMP_INSTALLER"
}

# --- 1. CHECK UPDATES BEFORE LAUNCH ---
check_for_updates

# =========================================================================
#                   GAME LAUNCH LOGIC
# =========================================================================

# --- CLEANUP ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print $1}' | xargs -r kill -9 2>/dev/null

# --- ENV VARS ---
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

# 5. Permissions
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

# 7. Write version
echo "$CURRENT_VERSION" > ~/.local/share/sober-fix-version

echo "=========================================="
echo " UPDATE SYSTEM INSTALLED (Ver $CURRENT_VERSION)"
echo "=========================================="
echo "The weird characters and ugly popup are fixed."
echo "Now using a clean Python UI."
