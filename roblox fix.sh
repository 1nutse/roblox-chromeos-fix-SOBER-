#!/bin/bash

# --- LOCAL VERSION (INSTALLER) ---
CURRENT_VERSION="1"

# 1. Ensure Dependencies (Weston, Xdotool, Python3-Tk)
# checking silently first to avoid sudo prompts if already installed
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing required packages..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk
fi

# 2. Grant Flatpak permissions
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. CREATE THE LAUNCH SCRIPT
# We use 'EOF' quoted to prevent variable expansion during creation.
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# --- CHANGELOG START ---
# Version 2.2:
# - Fixed text encoding issues (weird characters).
# - Removed system buttons (Yes/No); used custom English buttons only.
# - Cleaned up the Update GUI layout.
# - Enforced English language for all text.
# --- CHANGELOG END ---

# CURRENT SCRIPT VERSION
MY_VERSION="2.2"

# CONFIGURATION
VERSION_FILE="$HOME/.local/share/sober-fix-version"
# Time parameter (?t=) forces GitHub to serve the fresh file, bypassing cache
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh?t=$(date +%s)"
RAW_URL_NO_PARAM="https://github.com/1nutse/roblox-chromeos-fix-SOBER-/blob/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
PYTHON_UI_SCRIPT="/tmp/sober_update_ui.py"

# --- UPDATE CHECKER LOGIC ---
check_for_updates() {
    # 1. Download script silently
    if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_INSTALLER"; then
        
        # 2. Extract Remote Version (Search strictly for CURRENT_VERSION="X.X")
        REMOTE_VER=$(grep -o 'CURRENT_VERSION="[^"]*"' "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        
        # Fallback search if strict search fails
        if [ -z "$REMOTE_VER" ]; then
             REMOTE_VER=$(grep "CURRENT_VERSION=" "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        fi

        # 3. Compare Versions
        if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$MY_VERSION" ]; then
            
            # Extract Changelog cleanly
            CHANGELOG=$(sed -n '/# --- CHANGELOG START ---/,/# --- CHANGELOG END ---/p' "$TEMP_INSTALLER" | sed 's/# //g' | sed 's/--- CHANGELOG START ---//g' | sed 's/--- CHANGELOG END ---//g')
            
            if [ -z "$CHANGELOG" ]; then CHANGELOG="No changelog details available."; fi

            # 4. Generate Python GUI Script
            # We use cat <<PYEOF to inject Bash variables into Python code
            cat > "$PYTHON_UI_SCRIPT" <<PYEOF
import tkinter as tk
from tkinter import scrolledtext
import webbrowser
import sys

# Injected Variables
local_ver = "$MY_VERSION"
remote_ver = "$REMOTE_VER"
changelog_text = """$CHANGELOG"""
script_url = "$RAW_URL_NO_PARAM"

def on_update():
    root.destroy()
    sys.exit(10) # Exit 10 -> PROCEED UPDATE

def on_skip():
    root.destroy()
    sys.exit(0) # Exit 0 -> PLAY GAME

def on_view_code():
    webbrowser.open(script_url)

# Window Setup
root = tk.Tk()
root.title("Sober Fix Update")
root.geometry("500x420")
root.resizable(False, False)

# Main Container
main_frame = tk.Frame(root, padx=15, pady=15)
main_frame.pack(expand=True, fill="both")

# Header
tk.Label(main_frame, text="Update Available!", font=("Arial", 14, "bold"), fg="#d32f2f").pack(pady=(0, 10))

# Version Info Box
v_frame = tk.Frame(main_frame, relief="groove", borderwidth=2, padx=10, pady=8)
v_frame.pack(fill="x", pady=5)
tk.Label(v_frame, text=f"Current: {local_ver}", font=("Arial", 10)).pack(side="left")
tk.Label(v_frame, text=f"New: {remote_ver}", font=("Arial", 10, "bold"), fg="#2e7d32").pack(side="right")

# Changelog Section
tk.Label(main_frame, text="Changelog / Changes:", font=("Arial", 10, "bold"), anchor="w").pack(fill="x", pady=(15, 5))

# Text Area
txt = scrolledtext.ScrolledText(main_frame, height=8, font=("Consolas", 9), bg="#f0f0f0")
txt.insert(tk.END, changelog_text.strip())
txt.configure(state="disabled") # Read Only
txt.pack(fill="both", expand=True)

# Button Area
btn_frame = tk.Frame(main_frame, pady=15)
btn_frame.pack(fill="x")

# Left Button: View Code
tk.Button(btn_frame, text="View Script Code", command=on_view_code).pack(side="left")

# Right Buttons: Update & Skip
tk.Button(btn_frame, text="UPDATE NOW", bg="#007bff", fg="white", font=("Arial", 9, "bold"), padx=10, command=on_update).pack(side="right", padx=(10, 0))
tk.Button(btn_frame, text="Play without updating", command=on_skip).pack(side="right")

# Handle "X" button as Skip
root.protocol("WM_DELETE_WINDOW", on_skip)

root.mainloop()
PYEOF

            # 5. Run Python GUI
            python3 "$PYTHON_UI_SCRIPT"
            EXIT_CODE=$?
            rm -f "$PYTHON_UI_SCRIPT"

            # 6. Check Result
            if [ $EXIT_CODE -eq 10 ]; then
                chmod +x "$TEMP_INSTALLER"
                bash "$TEMP_INSTALLER"
                exit 0 # Terminate this script, installer takes over
            fi
            # If EXIT_CODE is 0, user clicked Play or closed window. We continue.
        fi
    fi
    rm -f "$TEMP_INSTALLER"
}

# RUN UPDATE CHECKER
check_for_updates

# =========================================================================
#                   WESTON / SOBER LAUNCH LOGIC
# =========================================================================

# --- CLEANUP PREVIOUS INSTANCES ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print $1}' | xargs -r kill -9 2>/dev/null

# --- ENVIRONMENT ---
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

# --- DRIVERS & STABILITY ---
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# --- MOUSE LOOP ---
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

# Wait for Wayland socket
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

# --- CLEANUP ---
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
echo "INSTALLATION COMPLETE (Version $CURRENT_VERSION)"
echo "=========================================="
echo "GUI Issues Fixed:"
echo "- Language forced to English (fixes encoding errors)."
echo "- Removed redundant system buttons."
echo "- Clean layout with 3 clear options."
echo ""
echo "Please launch 'Roblox (Sober Fix)' to verify."
