#!/bin/bash

# --- INSTALLER CONFIGURATION ---
INSTALL_VERSION="1"

# 1. VERIFY DEPENDENCIES
# We check silently first.
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing required packages (Weston, Xdotool, Python3-Tk)..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk
fi

# 2. FLATPAK PERMISSIONS
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. DIRECTORY SETUP
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. GENERATE LAUNCH SCRIPT
# We use 'EOF' (quoted) so variables are NOT expanded now, but written literally to the file.
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# --- CHANGELOG START ---
# Version 2.4:
# - REFACTOR: All critical variables defined at the very top.
# - Easier to maintain GitHub repository links.
# - Centralized configuration for Display and Paths.
# - Retains Upgrade/Downgrade detection logic.
# --- CHANGELOG END ---

# ==============================================================================
# 1. GLOBAL CONFIGURATION (DEFINE EVERYTHING HERE)
# ==============================================================================

# --- SCRIPT VERSION ---
MY_VERSION="1.1"

# --- GITHUB SETTINGS ---
GITHUB_USER="1nutse"
GITHUB_REPO="roblox-chromeos-fix-SOBER-"
GITHUB_BRANCH="main"
SCRIPT_FILENAME="roblox%20fix.sh" # encoded url

# --- UPDATE URLS (Constructed dynamically) ---
# We use a timestamp (?t=...) to bypass GitHub raw cache
CURRENT_TIME=$(date +%s)
UPDATE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/refs/heads/${GITHUB_BRANCH}/${SCRIPT_FILENAME}?t=${CURRENT_TIME}"
VIEW_CODE_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/blob/${GITHUB_BRANCH}/${SCRIPT_FILENAME}"

# --- FILE PATHS ---
VERSION_FILE="$HOME/.local/share/sober-fix-version"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
PYTHON_UI_SCRIPT="/tmp/sober_update_ui.py"
WESTON_LOG="/tmp/weston-sober.log"
WESTON_CONFIG_DIR="/tmp/weston-sober-config"

# --- WESTON / DISPLAY SETTINGS ---
export SOBER_DISPLAY="wayland-9"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# ==============================================================================
# 2. UPDATE CHECKER LOGIC
# ==============================================================================

check_for_updates() {
    # Download the remote script silently
    if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_INSTALLER"; then
        
        # Extract Remote Version (Look for MY_VERSION="X.X" or CURRENT_VERSION="X.X")
        # We search specifically for the variable definition at the top of the remote file
        REMOTE_VER=$(grep -o 'MY_VERSION="[^"]*"' "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        
        # Fallback for older script versions
        if [ -z "$REMOTE_VER" ]; then
             REMOTE_VER=$(grep "CURRENT_VERSION=" "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        fi

        # Compare Versions (String inequality check)
        if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$MY_VERSION" ]; then
            
            # Extract Changelog
            CHANGELOG=$(sed -n '/# --- CHANGELOG START ---/,/# --- CHANGELOG END ---/p' "$TEMP_INSTALLER" | sed 's/# //g' | sed 's/--- CHANGELOG START ---//g' | sed 's/--- CHANGELOG END ---//g')
            if [ -z "$CHANGELOG" ]; then CHANGELOG="No changelog details available."; fi

            # Generate Python GUI
            cat > "$PYTHON_UI_SCRIPT" <<PYEOF
import tkinter as tk
from tkinter import scrolledtext
import webbrowser
import sys

# --- INJECTED VARIABLES FROM BASH ---
local_ver = "$MY_VERSION"
remote_ver = "$REMOTE_VER"
changelog_text = """$CHANGELOG"""
script_url = "$VIEW_CODE_URL"

# --- LOGIC: DETECT DOWNGRADE VS UPGRADE ---
def get_parts(v):
    try: return [int(x) for x in v.split('.') if x.isdigit()]
    except: return [0]

l_parts = get_parts(local_ver)
r_parts = get_parts(remote_ver)

is_downgrade = r_parts < l_parts

# --- UI THEME CONFIG ---
if is_downgrade:
    ui_title = "Downgrade Available"
    ui_header_color = "#e65100" # Orange
    ui_btn_text = "DOWNGRADE"
    ui_btn_bg = "#ef6c00"
    msg_header = "Older Version Detected"
else:
    ui_title = "Update Available"
    ui_header_color = "#2e7d32" # Green
    ui_btn_text = "UPDATE NOW"
    ui_btn_bg = "#007bff"
    msg_header = "New Version Available"

# --- ACTIONS ---
def on_action():
    root.destroy()
    sys.exit(10) # Code 10 = Perform Action

def on_skip():
    root.destroy()
    sys.exit(0) # Code 0 = Skip

def on_view_code():
    webbrowser.open(script_url)

# --- GUI BUILD ---
root = tk.Tk()
root.title("Sober Fix - " + ui_title)
root.geometry("500x420")
root.resizable(False, False)

main_frame = tk.Frame(root, padx=15, pady=15)
main_frame.pack(expand=True, fill="both")

tk.Label(main_frame, text=msg_header, font=("Arial", 14, "bold"), fg=ui_header_color).pack(pady=(0, 10))

v_frame = tk.Frame(main_frame, relief="groove", borderwidth=2, padx=10, pady=8)
v_frame.pack(fill="x", pady=5)

tk.Label(v_frame, text=f"Current: {local_ver}", font=("Arial", 10)).pack(side="left")
r_fg = "#d32f2f" if is_downgrade else "#2e7d32"
tk.Label(v_frame, text=f"Remote: {remote_ver}", font=("Arial", 10, "bold"), fg=r_fg).pack(side="right")

tk.Label(main_frame, text="Changelog / Details:", font=("Arial", 10, "bold"), anchor="w").pack(fill="x", pady=(15, 5))

txt = scrolledtext.ScrolledText(main_frame, height=8, font=("Consolas", 9), bg="#f0f0f0")
txt.insert(tk.END, changelog_text.strip())
txt.configure(state="disabled")
txt.pack(fill="both", expand=True)

btn_frame = tk.Frame(main_frame, pady=15)
btn_frame.pack(fill="x")

tk.Button(btn_frame, text="View Code", command=on_view_code).pack(side="left")
tk.Button(btn_frame, text=ui_btn_text, bg=ui_btn_bg, fg="white", font=("Arial", 9, "bold"), padx=10, command=on_action).pack(side="right", padx=(10, 0))
tk.Button(btn_frame, text="Play without changing", command=on_skip).pack(side="right")

root.protocol("WM_DELETE_WINDOW", on_skip)
root.mainloop()
PYEOF

            # Run Python
            python3 "$PYTHON_UI_SCRIPT"
            EXIT_CODE=$?
            rm -f "$PYTHON_UI_SCRIPT"

            # Check Exit Code
            if [ $EXIT_CODE -eq 10 ]; then
                chmod +x "$TEMP_INSTALLER"
                bash "$TEMP_INSTALLER"
                exit 0 # Terminate current script
            fi
        fi
    fi
    rm -f "$TEMP_INSTALLER"
}

# RUN CHECKS
check_for_updates

# ==============================================================================
# 3. WESTON & SOBER LAUNCHER
# ==============================================================================

# --- CLEANUP ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print $1}' | xargs -r kill -9 2>/dev/null
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY"
rm -f "$XDG_RUNTIME_DIR/$SOBER_DISPLAY.lock"
rm -rf "$WESTON_CONFIG_DIR"
mkdir -p "$WESTON_CONFIG_DIR"

# --- WESTON CONFIG GENERATION ---
cat > "$WESTON_CONFIG_DIR/weston.ini" <<INNER_EOF
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

# --- DRIVER OVERRIDES ---
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# --- MOUSE FIX FUNCTION ---
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

# --- START WESTON ---
weston --config="$WESTON_CONFIG_DIR/weston.ini" --socket="$SOBER_DISPLAY" --fullscreen > "$WESTON_LOG" 2>&1 &
WPID=$!

start_infinite_mouse &
MOUSE_PID=$!

# Wait for Wayland Socket
for i in {1..50}; do
    if [ -S "$XDG_RUNTIME_DIR/$SOBER_DISPLAY" ]; then break; fi
    sleep 0.1
done

# --- START SOBER ---
WAYLAND_DISPLAY="$SOBER_DISPLAY" \
DISPLAY="" \
GDK_BACKEND=wayland \
QT_QPA_PLATFORM=wayland \
SDL_VIDEODRIVER=wayland \
CLUTTER_BACKEND=wayland \
flatpak run org.vinegarhq.Sober

# --- EXIT HANDLER ---
kill -TERM $WPID 2>/dev/null
kill $MOUSE_PID 2>/dev/null
rm -rf "$WESTON_CONFIG_DIR"
EOF

# 5. PERMISSIONS
chmod +x ~/.local/bin/launch-sober-weston.sh

# 6. DESKTOP ENTRY
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

# 7. VERSION TRACKING
echo "$INSTALL_VERSION" > ~/.local/share/sober-fix-version

echo "=========================================="
echo "INSTALLED VERSION: $INSTALL_VERSION"
echo "=========================================="
echo "Configuration is now centralized at the top of the script."
echo "Update/Downgrade detection is active."
