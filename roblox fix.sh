#!/bin/bash

# --- CONFIGURACIÓN DE VERSIÓN Y CAMBIOS ---
CURRENT_VERSION="1"
CHANGELOG="New update System!"

# 1. Ensure Weston and Zenity are installed
# Added 'zenity' for GUI dialogs
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! command -v zenity >/dev/null; then
    sudo apt-get update && sudo apt-get install -y weston xdotool zenity
fi

# 2. Grant Flatpak permissions for windowing system
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create required directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Create the optimized launch script
cat > ~/.local/bin/launch-sober-weston.sh <<EOF
#!/bin/bash

# --- AUTO UPDATE CHECK WITH USER PROMPT ---
VERSION_FILE="\$HOME/.local/share/sober-fix-version"
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
TEMP_INSTALLER="/tmp/roblox-fix-update.sh"

# Check for update (timeout 5s)
if curl -sS --max-time 5 "\$UPDATE_URL" -o "\$TEMP_INSTALLER"; then
    # Extract version from downloaded script
    REMOTE_VER=\$(grep '^CURRENT_VERSION=' "\$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
    # Extract Changelog from downloaded script
    REMOTE_LOG=\$(grep '^CHANGELOG=' "\$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
    
    LOCAL_VER=\$(cat "\$VERSION_FILE" 2>/dev/null || echo "0.0")
    
    # Compare versions
    if [ "\$REMOTE_VER" != "\$LOCAL_VER" ] && [ -n "\$REMOTE_VER" ]; then
        # Ask User via Zenity
        if zenity --question \
             --title="Actualización Disponible" \
             --text="Nueva versión detectada: \$REMOTE_VER\nVersión actual: \$LOCAL_VER\n\nCambios (Changelog):\n\$REMOTE_LOG\n\n¿Deseas actualizar ahora?" \
             --width=400; then
            
            # User clicked Yes
            chmod +x "\$TEMP_INSTALLER"
            bash "\$TEMP_INSTALLER"
            
            # Re-launch the (now updated) script
            exec "\$0"
        else
            # User clicked No - Update timestamp or just skip to launch
            echo "Actualización omitida por el usuario."
        fi
    fi
fi
rm -f "\$TEMP_INSTALLER"

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
    # Wait for Weston window to appear
    sleep 2
    
    # Get screen dimensions
    read SCREEN_WIDTH SCREEN_HEIGHT <<< \$(xdotool getdisplaygeometry)
    
    while true; do
        # Get current mouse position
        eval \$(xdotool getmouselocation --shell)
        
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
        
        sleep 0.005
    done
}

# --- START WESTON ---
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
echo "- $CHANGELOG"
echo ""
echo "You can launch the game via 'Roblox (Sober Fix)' in your menu."
