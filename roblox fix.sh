#!/bin/bash

# ==============================================================================
# CONFIGURATION & CHANGELOG
# ==============================================================================
CURRENT_VERSION="2.2"

# CHANGELOG TEXT (Must be inside quotes)
CHANGELOG_TEXT="
- Fixed: Update popup not appearing (Parsing logic improved).
- Fixed: Application now restarts automatically after update.
- Changed: All interface text translated to English.
- Improved: Changelog extraction now uses Python for reliability.
- Stability: Weston and Mouse loop logic remains untouched.
"
# ==============================================================================

# 1. Ensure Dependencies (Weston, Xdotool, Python3-tk)
echo "Checking dependencies..."
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! dpkg -s python3-tk >/dev/null 2>&1; then
    echo "Installing necessary packages (Weston, Python-tk, Xdotool)..."
    sudo apt-get update && sudo apt-get install -y weston xdotool python3-tk python3
fi

# 2. Grant Flatpak Permissions
echo "Granting Flatpak permissions..."
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create Directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Create the Optimized Launch Script
echo "Generating launcher script..."
cat > ~/.local/bin/launch-sober-weston.sh <<EOF
#!/bin/bash

# ==============================================================================
# VARIABLES
# ==============================================================================
LOCAL_VERSION="$CURRENT_VERSION"
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
REPO_URL="https://github.com/1nutse/roblox-chromeos-fix-SOBER-"

# ==============================================================================
# PYTHON GUI UPDATER
# ==============================================================================
show_update_popup() {
    local remote_ver="\$1"
    
    # Run Python GUI
    python3 -c "
import tkinter as tk
from tkinter import ttk, scrolledtext
import webbrowser
import sys
import os

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
root.geometry('520x480')
root.resizable(False, False)

# Styling
style = ttk.Style()
style.theme_use('clam')

# Main Container
main_frame = ttk.Frame(root, padding='20')
main_frame.pack(fill='both', expand=True)

# Header
ttk.Label(main_frame, text='New Version Available!', font=('Helvetica', 16, 'bold')).pack(pady=(0, 5))
ttk.Label(main_frame, text=f'Current: $LOCAL_VERSION  ➜  New: {remote_ver}', font=('Helvetica', 11)).pack(pady=(0, 15))

# Changelog Label
ttk.Label(main_frame, text='Changelog / What\'s New:', font=('Helvetica', 10, 'bold')).pack(anchor='w')

# Get Changelog from Environment Variable (Safe method)
changelog_text = os.environ.get('REMOTE_CHANGELOG', 'No changelog info available.')

# Text Area
txt = scrolledtext.ScrolledText(main_frame, height=12, font=('Consolas', 9))
txt.insert(tk.END, changelog_text.strip())
txt.configure(state='disabled') # Read only
txt.pack(fill='both', expand=True, pady=(5, 15))

# Buttons
btn_frame = ttk.Frame(main_frame)
btn_frame.pack(fill='x')

ttk.Button(btn_frame, text='View Code', command=open_url).pack(side='left')
ttk.Button(btn_frame, text='Update Now', command=on_update).pack(side='right', padx=(5, 0))
ttk.Button(btn_frame, text='Skip & Play', command=on_skip).pack(side='right')

# Center Window
root.update_idletasks()
width = root.winfo_width()
height = root.winfo_height()
x = (root.winfo_screenwidth() // 2) - (width // 2)
y = (root.winfo_screenheight() // 2) - (height // 2)
root.geometry(f'{width}x{height}+{x}+{y}')

root.mainloop()
"
}

# ==============================================================================
# UPDATE CHECK LOGIC
# ==============================================================================
# 1. Download Remote Script
if curl -sS --max-time 5 "\$UPDATE_URL" -o "\$TEMP_INSTALLER"; then
    
    # 2. Extract Version (Bash)
    REMOTE_VER=\$(grep '^CURRENT_VERSION=' "\$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
    
    # 3. Extract Changelog (Using Python for robustness)
    # This prevents failures with multiline strings in bash/sed
    REMOTE_CHANGELOG_TEXT=\$(python3 -c "
import re
try:
    with open('\$TEMP_INSTALLER', 'r') as f:
        content = f.read()
    match = re.search(r'CHANGELOG_TEXT=\"(.*?)\"', content, re.DOTALL)
    if match:
        print(match.group(1))
    else:
        print('Changelog not found in remote file.')
except Exception as e:
    print('Error parsing changelog.')
")

    # 4. Compare Versions
    # Note: If versions are identical, popup will NOT show.
    if [ "\$REMOTE_VER" != "\$LOCAL_VERSION" ] && [ -n "\$REMOTE_VER" ]; then
        
        # Export for Python GUI
        export REMOTE_CHANGELOG="\$REMOTE_CHANGELOG_TEXT"
        
        # Show Popup
        USER_CHOICE=\$(show_update_popup "\$REMOTE_VER")
        
        if [ "\$USER_CHOICE" == "UPDATE" ]; then
            echo "User accepted update..."
            chmod +x "\$TEMP_INSTALLER"
            
            # Execute the new installer
            bash "\$TEMP_INSTALLER"
            
            # RESTART THE SCRIPT AUTOMATICALLY
            # This replaces the current running process with the new one
            echo "Restarting application..."
            exec "\$0"
            
        elif [ "\$USER_CHOICE" == "SKIP" ]; then
            echo "Update skipped."
        fi
    fi
fi
rm -f "\$TEMP_INSTALLER"

# ==============================================================================
# WESTON & SOBER LAUNCHER (UNCHANGED CORE)
# ==============================================================================

# --- CLEANUP ---
pkill -9 -x "sober" 2>/dev/null
pkill -9 -x "weston" 2>/dev/null
flatpak ps | grep "org.vinegarhq.Sober" | awk '{print \$1}' | xargs -r kill -9 2>/dev/null

# --- ENV VARS ---
export SOBER_DISPLAY="wayland-9"
if [ -z "\$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
fi

CONFIG_DIR="/tmp/weston-sober-config"
mkdir -p "\$CONFIG_DIR"
rm -f "\$XDG_RUNTIME_DIR/\$SOBER_DISPLAY"
rm -f "\$XDG_RUNTIME_DIR/\$SOBER_DISPLAY.lock"

# --- WESTON CONFIG ---
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

# --- DRIVER FIXES ---
export X11_NO_MITSHM=1
export VIRGL_DEBUG=no_fbo_cache
export mesa_glthread=true

# --- MOUSE LOOP ---
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

# --- LAUNCH WESTON ---
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

# 5. Make Executable
chmod +x ~/.local/bin/launch-sober-weston.sh

# 6. Desktop Shortcut
echo "Creating Desktop entry..."
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
echo "The update system has been patched."
echo "You can now launch 'Roblox (Sober Fix)' from your menu."
