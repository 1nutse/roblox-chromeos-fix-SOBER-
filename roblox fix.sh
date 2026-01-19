#!/bin/bash
sudo apt-get update && sudo apt-get install -y weston xdotool
mkdir -p ~/.local/bin ~/.local/share/applications
cat > ~/.local/bin/launch-sober-weston.sh <<'EOF'
#!/bin/bash
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        export XDG_RUNTIME_DIR="/tmp/weston-runtime-$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 0700 "$XDG_RUNTIME_DIR"
    fi
fi

# --- INFINITE MOUSE LOOP ---
start_infinite_mouse() {
    # Wait for Weston window to appear
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

CONFIG_DIR=/tmp/weston-sober-config
mkdir -p $CONFIG_DIR
cat > $CONFIG_DIR/weston.ini <<INNER_EOF
[core]
backend=x11-backend.so
shell=kiosk-shell.so
[shell]
locking=true
[output]
name=WestonWindow
mode=1280x720
INNER_EOF
rm -f "$XDG_RUNTIME_DIR/wayland-sober"
weston --fullscreen --config=$CONFIG_DIR/weston.ini --socket=wayland-sober > /tmp/weston.log 2>&1 &
WPID=$!

# Start infinite mouse loop in background
start_infinite_mouse &
MOUSE_PID=$!

sleep 2
if [ ! -S "$XDG_RUNTIME_DIR/wayland-sober" ]; then
    echo "Error iniciando Weston"
    kill $WPID
    kill $MOUSE_PID 2>/dev/null
    exit 1
fi
WAYLAND_DISPLAY=wayland-sober GDK_BACKEND=wayland QT_QPA_PLATFORM=wayland SDL_VIDEODRIVER=wayland flatpak run org.vinegarhq.Sober
kill $WPID
kill $MOUSE_PID 2>/dev/null
rm -rf $CONFIG_DIR
EOF
chmod +x ~/.local/bin/launch-sober-weston.sh
printf "[Desktop Entry]\nName=Roblox (Sober Fix)\nComment=Play Roblox with Weston Mouse & Audio Fix\nExec=$HOME/.local/bin/launch-sober-weston.sh\nIcon=org.vinegarhq.Sober\nTerminal=false\nType=Application\nCategories=Game;\n" > ~/.local/share/applications/sober-fix.desktop
chmod +x ~/.local/share/applications/sober-fix.desktop
