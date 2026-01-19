#!/bin/bash

# Define version for the installer itself (matches the one injected below)
CURRENT_VERSION="1.1"

# 1. Ensure Weston and YAD (for popups) are installed
# Added 'yad' to the install list as requested (alternative to Zenity)
if ! command -v weston >/dev/null || ! command -v xdotool >/dev/null || ! command -v yad >/dev/null; then
    echo "Installing necessary dependencies (Weston, Xdotool, YAD)..."
    sudo apt-get update && sudo apt-get install -y weston xdotool yad
fi

# 2. Grant Flatpak permissions for windowing system
flatpak override --user --socket=wayland --socket=x11 org.vinegarhq.Sober

# 3. Create required directories
mkdir -p ~/.local/bin ~/.local/share/applications

# 4. Create the optimized launch script with Update GUI
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash

# --- CONFIGURATION & VERSIONING ---
CURRENT_VERSION="1.1"
UPDATE_URL="https://raw.githubusercontent.com/1nutse/roblox-chromeos-fix-SOBER-/refs/heads/main/roblox%20fix.sh"
VERSION_FILE="$HOME/.local/share/sober-fix-version"

# --- CHANGELOG SECTION ---
# This variable holds the history of changes to be displayed in the popup
CHANGELOG_TEXT="
v1.1
- Added automatic GUI update checker (YAD).
- Integrated Changelog viewer.
- Added options to View Code, Update, or Skip.

v1.0
- Initial stable release.
- Fixed 'Frozen Instance' error.
- Implemented Infinite Mouse Loop.
- Optimized Weston/Mesa drivers.
"

# --- UPDATE CHECK FUNCTION ---
check_for_updates() {
    TEMP_INSTALLER="/tmp/roblox-fix-update.sh"
    
    # Download remote script silently (timeout 5s)
    if curl -sS --max-time 5 "$UPDATE_URL" -o "$TEMP_INSTALLER"; then
        
        # Extract version from downloaded script
        REMOTE_VER=$(grep '^CURRENT_VERSION=' "$TEMP_INSTALLER" | head -n 1 | cut -d'"' -f2)
        
        # If remote version exists and is different from local
        if [ "$REMOTE_VER" != "$CURRENT_VERSION" ] && [ -n "$REMOTE_VER" ]; then
            
            # Extract changelog from remote file to show the user what's new
            # (We attempt to parse the variable CHANGELOG_TEXT from the remote file)
            REMOTE_LOG=$(sed -n '/CHANGELOG_TEXT="/,/"/p' "$TEMP_INSTALLER" | tr -d '"' | sed 's/CHANGELOG_TEXT=//')

            # Show YAD Popup
            # Return codes: 0=Update, 1=Skip, 2=View Code
            yad --title="Sober Fix - Update Available" \
                --window-icon="system-software-update" \
                --center \
                --width=500 --height=400 \
                --text="<b>A new version ($REMOTE_VER) is available!</b>\nCurrent version: $CURRENT_VERSION\n\n<b>Changelog:</b>" \
                --text-info \
                --text-align=left \
                --fore=#000000 --back=#f0f0f0 \
                --margins=10 \
                --button="Update Now!gtk-ok":0 \
                --button="Skip Update!gtk-close":1 \
                --button="View Code!gtk-find":2 \
                <<< "$REMOTE_LOG"
            
            ACTION=$?

            if [ "$ACTION" -eq 0 ]; then
                # UPDATE
                echo "Updating script..."
                chmod +x "$TEMP_INSTALLER"
                bash "$TEMP_INSTALLER"
                exit 0
            elif [ "$ACTION" -eq 2 ]; then
                # VIEW CODE
                echo "Opening GitHub..."
                xdg-open "https://github.com/1nutse/roblox-chromeos-fix-SOBER-/blob/main/roblox%20fix.sh"
                exit 0
            else
                # SKIP (Action 1 or closed window)
                echo "Skipping update..."
            fi
        fi
    fi
    rm -f "$TEMP_INSTALLER"
}

# Run the update check BEFORE starting Weston
check_for_updates

# ==============================================================================
#                 CORE APPLICATION LOGIC (WESTON + SOBER)
# ==============================================================================

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
    # Wait for Weston window to appear (optional, but good practice)
    sleep 2
    
    # Get screen dimensions
    read SCREEN_WIDTH SCREEN_HEIGHT <<< $(xdotool getdisplaygeometry)
    
    while true; do
        # Get current mouse position
        eval $(xdotool getmouselocation --shell)
        # X and Y are set by eval
        
        NEW_X=$X
        NEW_Y=$Y
        CHANGED=0
        
        # Left edge -> Right edge
        if [ "$X" -le 0 ]; then
            NEW_X=$((SCREEN_WIDTH - 2))
            CHANGED=1
        # Right edge -> Left edge
        elif [ "$X" -ge $((SCREEN_WIDTH - 1)) ]; then
            NEW_X=1
            CHANGED=1
        fi
        
        # Top edge -> Bottom edge
        if [ "$Y" -le 0 ]; then
            NEW_Y=$((SCREEN_HEIGHT - 2))
            CHANGED=1
        # Bottom edge -> Top edge
        elif [ "$Y" -ge $((SCREEN_HEIGHT - 1)) ]; then
            NEW_Y=1
            CHANGED=1
        fi
        
        if [ "$CHANGED" -eq 1 ]; then
            xdotool mousemove $NEW_X $NEW_Y
        fi
        
        # Sleep briefly to avoid high CPU but keep it responsive
        sleep 0.005
    done
}

# --- START WESTON ---
# Added --fullscreen to make it fullscreen
weston --config="$CONFIG_DIR/weston.ini" --socket="$SOBER_DISPLAY" --fullscreen > /tmp/weston-sober.log 2>&1 &
WPID=$!

# Start infinite mouse loop in background
start_infinite_mouse &
MOUSE_PID=$!

# Wait for socket
for i in {1..50}; do
    if [ -S "$XDG_RUNTIME_DIR/$SOBER_DISPLAY" ]; then
        break
    fi
    sleep 0.1
done

# --- LAUNCH SOBER ---
# Isolation: Use Wayland only to prevent conflicts with host X11
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

# 7. Write version file (for external checks if needed)
echo "$CURRENT_VERSION" > ~/.local/share/sober-fix-version

echo "=========================================="
echo "SYSTEM UPDATED AND READY (Version $CURRENT_VERSION)"
echo "=========================================="
echo "Applied changes:"
echo "- Added 'YAD' for update popups."
echo "- Added Changelog view inside the launcher."
echo "- Maintained Weston and Infinite Mouse fixes."
echo ""
echo "You can launch the game via 'Roblox (Sober Fix)' in your menu."
