#!/bin/bash

# ==============================================================================
# CONFIGURATION & CHANGELOG
# ==============================================================================
# Esta variable define la versión tanto para la comprobación local como remota.
CURRENT_VERSION="2432324.5"

# Escribe aquí los cambios. El actualizador extraerá esto para mostrarlo en el popup.
CHANGELOG_TEXT="
- Added Python-based GUI update checker (No Zenity).
- Added Changelog display in the updater.
- Added 'View Script' button to inspect code before updating.
- Maintained all specific Weston/Mesa configurations.
- Fixed logic to prevent Weston from starting if update is pending.
"
# ==============================================================================

# 1. Ensure Dependencies (Weston, Xdotool, Python3-tk for the popup)
# Added python3-tk to ensure the popup works
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing necessary dependencies..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk python3
fi

# 2. Grant Flatpak permissions
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Create the optimized launch script with embedded Python Updater
cat > ~/.local/bin/launch-sober-weston.sh <<EOF
#!/bin/bash

# ==============================================================================
# VARIABLES & PATHS
# ==============================================================================
# Variables injectadas desde el instalador
LOCAL_VERSION="$CURRENT_VERSION"
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
REPO_URL="https://github.com/1nutse/roblox-chromeos-fix-SOBER-"

# ==============================================================================
# PYTHON GUI UPDATER FUNCTION
# ==============================================================================
show_update_popup() {
    local remote_ver="\$1"
    local changelog="\$2"
    
    # Python script embedded
    python3 -c "
import tkinter as tk
from tkinter import ttk, scrolledtext
import webbrowser
import sys

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
root.geometry('500x450')
root.resizable(False, False)

# Style
style = ttk.Style()
style.theme_use('clam')

# Main Frame
main_frame = ttk.Frame(root, padding='20')
main_frame.pack(fill='both', expand=True)

# Header
header = ttk.Label(main_frame, text='New Version Available!', font=('Helvetica', 16, 'bold'))
header.pack(pady=(0, 10))

info_lbl = ttk.Label(main_frame, text=f'Local Version: $LOCAL_VERSION  |  New Version: {remote_ver}', font=('Helvetica', 10))
info_lbl.pack(pady=(0, 10))

# Changelog Area
lbl_change = ttk.Label(main_frame, text='Changelog:', font=('Helvetica', 10, 'bold'))
lbl_change.pack(anchor='w')

txt = scrolledtext.ScrolledText(main_frame, height=10, font=('Consolas', 9))
txt.insert(tk.END, '''$changelog''')
txt.configure(state='disabled') # Read only
txt.pack(fill='both', expand=True, pady=(5, 15))

# Buttons Frame
btn_frame = ttk.Frame(main_frame)
btn_frame.pack(fill='x')

btn_view = ttk.Button(btn_frame, text='View Script (Web)', command=open_url)
btn_view.pack(side='left')

btn_skip = ttk.Button(btn_frame, text='Skip Update', command=on_skip)
btn_skip.pack(side='right', padx=(5, 0))

btn_update = ttk.Button(btn_frame, text='Update Now', command=on_update)
btn_update.pack(side='right')

# Center window
root.eval('tk::PlaceWindow . center')

root.mainloop()
"
}

# ==============================================================================
# UPDATE CHECK LOGIC
# ==============================================================================
# Download remote script silently
if curl -sS --max-time 5 "\$UPDATE_URL" -o "\$TEMP_INSTALLER"; then
    
    # Extract Remote Version safely
    REMOTE_VER=\$(grep '^CURRENT_VERSION=' "\$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
    
    # Extract Remote Changelog (Parses text between CHANGELOG_TEXT=" and the closing quote)
    # Using perl for multiline matching because sed is tricky with newlines in variables
    REMOTE_CHANGELOG=\$(perl -0777 -ne 'print \$1 if /CHANGELOG_TEXT="(.*?)"/s' "\$TEMP_INSTALLER")

    # If versions match or remote is empty, do nothing. If different, show popup.
    if [ "\$REMOTE_VER" != "\$LOCAL_VERSION" ] && [ -n "\$REMOTE_VER" ]; then
        
        # Run Python Popup and capture output (UPDATE or SKIP)
        USER_CHOICE=\$(show_update_popup "\$REMOTE_VER" "\$REMOTE_CHANGELOG")
        
        if [ "\$USER_CHOICE" == "UPDATE" ]; then
            echo "Updating..."
            chmod +x "\$TEMP_INSTALLER"
            bash "\$TEMP_INSTALLER"
            exit 0 # Exit this old script, the new installer handles the rest
        elif [ "\$USER_CHOICE" == "SKIP" ]; then
            echo "Update skipped by user."
        fi
    fi
fi
rm -f "\$TEMP_INSTALLER"

# ==============================================================================
# WESTON & SOBER LAUNCH LOGIC (Original & Stable)
# ==============================================================================

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

# --- START WESTON ---
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

echo "=========================================="
echo "SYSTEM UPDATED AND READY (Version $CURRENT_VERSION)"
echo "=========================================="
echo "Features applied:"
echo "- Python GUI Update Checker included."
echo "- Auto-Changelog reader."
echo "- Graphics/Mouse fixes maintained."
echo ""
echo "Launch 'Roblox (Sober Fix)' to test the update system."
