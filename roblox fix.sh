#!/bin/bash

# Updated version variable for the installer itself
CURRENT_VERSION="1"

# 1. Ensure Weston, xdotool AND python3-tk are installed
# Added python3-tk to create the UI without Zenity
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing necessary dependencies (Weston, Xdotool, Python3-Tk)..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk
fi

# 2. Grant Flatpak permissions for windowing system
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create required directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Create the optimized launch script with Python GUI
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# --- CHANGELOG START ---
# Version 2.0:
# - Added interactive Update GUI (No Zenity).
# - You can now view changelogs before updating.
# - Added "View Script" button.
# - Fixed rendering flags for better performance.
# --- CHANGELOG END ---

CURRENT_VERSION="2.0"
VERSION_FILE="$HOME/.local/share/sober-fix-version"
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"

# --- PYTHON GUI UPDATE CHECKER ---
check_updates_gui() {
    # Download remote script silently
    if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_INSTALLER"; then
        REMOTE_VER=$(grep '^CURRENT_VERSION=' "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        LOCAL_VER="$CURRENT_VERSION"

        # Only show GUI if versions differ and remote is not empty
        if [ "$REMOTE_VER" != "$LOCAL_VER" ] && [ -n "$REMOTE_VER" ]; then
            
            # Extract Changelog from downloaded file
            CHANGELOG=$(sed -n '/# --- CHANGELOG START ---/,/# --- CHANGELOG END ---/p' "$TEMP_INSTALLER" | sed 's/# //g' | sed 's/--- CHANGELOG START ---//g' | sed 's/--- CHANGELOG END ---//g')
            
            # Export variables for Python
            export REMOTE_VER LOCAL_VER CHANGELOG UPDATE_URL
            
            # Run Python GUI
            python3 -c '
import tkinter as tk
from tkinter import messagebox, scrolledtext
import webbrowser
import sys
import os

def do_update():
    sys.exit(10) # Exit code 10 means UPDATE

def do_skip():
    sys.exit(0) # Exit code 0 means CONTINUE

def open_url():
    webbrowser.open(os.environ["UPDATE_URL"])

# Window Setup
root = tk.Tk()
root.title("Sober Fix - Update Available")
root.geometry("500x400")

# Center content
frame = tk.Frame(root, padx=20, pady=20)
frame.pack(expand=True, fill="both")

# Header
lbl_header = tk.Label(frame, text=f"Update Available!", font=("Arial", 16, "bold"))
lbl_header.pack(pady=(0, 10))

# Version Info
v_frame = tk.Frame(frame)
v_frame.pack(fill="x", pady=5)
tk.Label(v_frame, text=f"Current Version: {os.environ.get("LOCAL_VER")}", fg="gray").pack(side="left")
tk.Label(v_frame, text=f"New Version: {os.environ.get("REMOTE_VER")}", fg="green", font=("Arial", 10, "bold")).pack(side="right")

# Changelog Area
tk.Label(frame, text="Changelog:", font=("Arial", 10, "bold"), anchor="w").pack(fill="x", pady=(10, 0))
txt = scrolledtext.ScrolledText(frame, height=10, font=("Consolas", 9))
txt.insert(tk.INSERT, os.environ.get("CHANGELOG", "No changelog available."))
txt.configure(state="disabled") # Read only
txt.pack(fill="both", expand=True, pady=5)

# Buttons
btn_frame = tk.Frame(frame)
btn_frame.pack(fill="x", pady=10)

btn_view = tk.Button(btn_frame, text="View Script (Web)", command=open_url)
btn_view.pack(side="left")

btn_skip = tk.Button(btn_frame, text="Play Without Updating", command=do_skip)
btn_skip.pack(side="right", padx=5)

btn_update = tk.Button(btn_frame, text="UPDATE NOW", bg="#007bff", fg="white", command=do_update)
btn_update.pack(side="right")

# Prevent closing without choice (optional, or treat close as skip)
root.protocol("WM_DELETE_WINDOW", do_skip)

root.mainloop()
'
            # Capture Python exit code
            EXIT_CODE=$?
            
            if [ $EXIT_CODE -eq 10 ]; then
                echo "User chose to update."
                chmod +x "$TEMP_INSTALLER"
                bash "$TEMP_INSTALLER"
                exit 0 # Stop this script, the new one will run or has run
            fi
            # If exit code is 0, we continue to launch
        fi
    fi
    rm -f "$TEMP_INSTALLER"
}

# Run the update checker BEFORE starting anything else
check_updates_gui

# =========================================================================
#                   EXISTING LAUNCH LOGIC BELOW
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
echo "SYSTEM UPDATED (Version $CURRENT_VERSION)"
echo "=========================================="
echo "New features:"
echo "- Update Popup (GUI) added using Python/Tkinter."
echo "- Changelog viewer integrated."
echo "- Auto-launch disabled if update is pending user action."
echo ""
echo "Launch 'Roblox (Sober Fix)' to test."
