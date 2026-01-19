#!/bin/bash

# ==========================================
# CONFIGURATION & CHANGELOG (Edit this for new versions)
# ==========================================
CURRENT_VERSION="3242" 

# Use \n for line breaks in the changelog
CHANGELOG="
- Added Python-based Update GUI.
- Fixed infinite loop mouse logic.
- Improved Weston stability.
- Now asks user before updating.
"
# ==========================================

# 1. Ensure Dependencies are installed
# Added python3 and python3-tk for the GUI popup
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! command -v python3 >/dev/null; then
    echo "Installing necessary dependencies (Weston, Xdotool, Python3)..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3 python3-tk
fi

# 2. Grant Flatpak permissions for windowing system
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create required directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Create the optimized launch script
# We use a quoted heredoc (EOF) to prevent variable expansion during creation,
# EXCEPT for the version/changelog injection which we handle via sed afterwards or careful structure.
# To keep it robust, we will inject the version variables dynamically.

LAUNCHER_PATH="$HOME/.local/bin/launch-sober-weston.sh"

cat > "$LAUNCHER_PATH" <<EOF
#!/bin/bash

# --- CONFIGURATION ---
LOCAL_VERSION="$CURRENT_VERSION"
VERSION_FILE="\$HOME/.local/share/sober-fix-version"
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
TEMP_UI_SCRIPT="/tmp/sober_update_ui.py"

# --- CHECK FOR UPDATES ---
# Download the remote script quietly to check version
if curl -sS --max-time 5 "\$UPDATE_URL" -o "\$TEMP_INSTALLER"; then
    
    # Extract Remote Version (looking for CURRENT_VERSION="X")
    REMOTE_VER=\$(grep '^CURRENT_VERSION=' "\$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
    
    # Extract Remote Changelog (Simple extraction between quotes)
    # This reads the CHANGELOG="..." variable from the remote file
    REMOTE_CHANGELOG=\$(grep -zPo 'CHANGELOG="\K[^"]*' "\$TEMP_INSTALLER" | tr -d '\0')
    
    # Default if changelog extraction fails
    if [ -z "\$REMOTE_CHANGELOG" ]; then
        REMOTE_CHANGELOG="See GitHub for details."
    fi

    # Compare Versions
    if [ "\$REMOTE_VER" != "\$LOCAL_VERSION" ] && [ -n "\$REMOTE_VER" ]; then
        
        # --- GENERATE PYTHON POPUP ---
        cat > "\$TEMP_UI_SCRIPT" <<PYEOF
import tkinter as tk
from tkinter import ttk, scrolledtext
import webbrowser
import sys

def open_url():
    webbrowser.open("\$UPDATE_URL")

def on_update():
    print("UPDATE")
    root.destroy()

def on_continue():
    print("CONTINUE")
    root.destroy()

root = tk.Tk()
root.title("Roblox (Sober) Update")
root.geometry("500x400")
root.resizable(False, False)

# Style
style = ttk.Style()
style.theme_use('clam')

# Header
header_frame = tk.Frame(root, pady=10)
header_frame.pack()
tk.Label(header_frame, text="New Update Available!", font=("Arial", 14, "bold"), fg="#e74c3c").pack()
tk.Label(header_frame, text=f"Local Version: \$LOCAL_VERSION  |  New Version: \$REMOTE_VER", font=("Arial", 10)).pack()

# Changelog Area
tk.Label(root, text="Changelog:", font=("Arial", 10, "bold"), anchor="w").pack(fill="x", padx=20)
text_area = scrolledtext.ScrolledText(root, wrap=tk.WORD, width=50, height=10, font=("Consolas", 9))
text_area.pack(padx=20, pady=5)
text_area.insert(tk.INSERT, """\$REMOTE_CHANGELOG""")
text_area.configure(state='disabled')

# Buttons
btn_frame = tk.Frame(root, pady=20)
btn_frame.pack(side=tk.BOTTOM, fill="x")

tk.Button(btn_frame, text="View Script Code", command=open_url, fg="blue", relief="flat").pack(side=tk.TOP, pady=5)

action_frame = tk.Frame(btn_frame)
action_frame.pack(side=tk.TOP)

tk.Button(action_frame, text="Continue without updating", command=on_continue, padx=10, pady=5).pack(side=tk.LEFT, padx=10)
tk.Button(action_frame, text="Update Now", command=on_update, bg="#2ecc71", fg="white", font=("Arial", 10, "bold"), padx=10, pady=5).pack(side=tk.LEFT, padx=10)

# Bring to front
root.lift()
root.attributes('-topmost',True)
root.after_idle(root.attributes,'-topmost',False)

root.protocol("WM_DELETE_WINDOW", on_continue) # X button continues without update
root.mainloop()
PYEOF

        # Run Python Script and capture output
        USER_CHOICE=\$(python3 "\$TEMP_UI_SCRIPT")
        rm -f "\$TEMP_UI_SCRIPT"

        if [ "\$USER_CHOICE" == "UPDATE" ]; then
            echo "Updating..."
            chmod +x "\$TEMP_INSTALLER"
            bash "\$TEMP_INSTALLER"
            exit 0
        fi
        # If CONTINUE or anything else, proceed to launch game
    fi
fi
rm -f "\$TEMP_INSTALLER"

# =========================================================================
#       CORE LAUNCHER LOGIC (WESTON + SOBER)
# =========================================================================

# --- CLEANUP PREVIOUS INSTANCES ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print \$1}' | xargs -r kill -9 2>/dev/null

# --- ENVIRONMENT CONFIGURATION ---
export SOBER_DISPLAY="wayland-9"
if [ -z "\$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
fi

CONFIG_DIR="/tmp/weston-sober-config"
mkdir -p "\$CONFIG_DIR"
rm -f "\$XDG_RUNTIME_DIR/\$SOBER_DISPLAY"
rm -f "\$XDG_RUNTIME_DIR/\$SOBER_DISPLAY.lock"

# --- WESTON CONFIGURATION ---
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

# --- STABILITY VARIABLES (X11 + Drivers) ---
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# --- INFINITE MOUSE LOOP ---
start_infinite_mouse() {
    # Wait for Weston window to appear (optional, but good practice)
    sleep 2
    
    # Get screen dimensions
    read SCREEN_WIDTH SCREEN_HEIGHT <<< \$(xdotool getdisplaygeometry)
    
    while true; do
        # Get current mouse position
        eval \$(xdotool getmouselocation --shell)
        # X and Y are set by eval
        
        NEW_X=\$X
        NEW_Y=\$Y
        CHANGED=0
        
        # Left edge -> Right edge
        if [ "\$X" -le 0 ]; then
            NEW_X=\$((SCREEN_WIDTH - 2))
            CHANGED=1
        # Right edge -> Left edge
        elif [ "\$X" -ge \$((SCREEN_WIDTH - 1)) ]; then
            NEW_X=1
            CHANGED=1
        fi
        
        # Top edge -> Bottom edge
        if [ "\$Y" -le 0 ]; then
            NEW_Y=\$((SCREEN_HEIGHT - 2))
            CHANGED=1
        # Bottom edge -> Top edge
        elif [ "\$Y" -ge \$((SCREEN_HEIGHT - 1)) ]; then
            NEW_Y=1
            CHANGED=1
        fi
        
        if [ "\$CHANGED" -eq 1 ]; then
            xdotool mousemove \$NEW_X \$NEW_Y
        fi
        
        # Sleep briefly to avoid high CPU but keep it responsive
        sleep 0.005
    done
}

# --- START WESTON ---
# Added --fullscreen to make it fullscreen
weston --config="\$CONFIG_DIR/weston.ini" --socket="\$SOBER_DISPLAY" --fullscreen > /tmp/weston-sober.log 2>&1 &
WPID=\$!

# Start infinite mouse loop in background
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
# Isolation: Use Wayland only to prevent conflicts with host X11
WAYLAND_DISPLAY="\$SOBER_DISPLAY" \
DISPLAY="" \
GDK_BACKEND=wayland \
QT_QPA_PLATFORM=wayland \
SDL_VIDEODRIVER=wayland \
CLUTTER_BACKEND=wayland \
flatpak run org.vinegarhq.Sober

# --- EXIT CLEANUP ---
kill -TERM \$WPID 2>/dev/null
kill \$MOUSE_PID 2>/dev/null
rm -rf "\$CONFIG_DIR"
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
echo "SYSTEM UPDATED AND READY (Version $CURRENT_VERSION)"
echo "=========================================="
echo "Applied changes:"
echo "- Update mechanism: Added Python GUI Popup."
echo "- Changelog viewer included."
echo "- Core Weston/Sober rendering unchanged."
echo ""
echo "You can launch the game via 'Roblox (Sober Fix)' in your menu."
