#!/bin/bash
ulimit -c 0

# Desktop shortcuts
if [ ! -f $HOME/Desktop/lm-studio.desktop ]; then
  mkdir -p $HOME/Desktop
  cp /usr/share/applications/lm-studio.desktop $HOME/Desktop/
  chmod +x $HOME/Desktop/lm-studio.desktop
  cp /defaults/lms.desktop $HOME/Desktop/
  chmod +x $HOME/Desktop/lms.desktop
  cp /usr/share/applications/org.kde.konsole.desktop $HOME/Desktop/
  chmod +x $HOME/Desktop/org.kde.konsole.desktop
fi

# Default configs
if [ ! -f $HOME/.config/opencode/opencode.json ]; then
  mkdir -p "$HOME/.config/opencode"
  cp /defaults/opencode.json "$HOME/.config/opencode/"
fi

# Disable compositing and screen locking
if [ ! -f $HOME/.config/kwinrc ]; then
  kwriteconfig6 --file $HOME/.config/kwinrc --group Compositing --key Enabled false
fi
if [ ! -f $HOME/.config/kscreenlockerrc ]; then
  kwriteconfig6 --file $HOME/.config/kscreenlockerrc --group Daemon --key Autolock false
fi

# Power related
setterm blank 0
setterm powerdown 0

# Setup permissive clipboard rules
KWIN_RULES_FILE="$HOME/.config/kwinrulesrc"
RULE_DESC="wl-clipboard support"
if ! grep -q "$RULE_DESC" "$KWIN_RULES_FILE" 2>/dev/null; then
  echo "Applying KWin clipboard rule..."
  if command -v uuidgen &> /dev/null; then
    RULE_ID=$(uuidgen)
  else
    RULE_ID=$(cat /proc/sys/kernel/random/uuid)
  fi
  count=$(kreadconfig6 --file "$KWIN_RULES_FILE" --group General --key count --default 0)
  new_count=$((count + 1))
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group General --key count "$new_count"
  existing_rules=$(kreadconfig6 --file "$KWIN_RULES_FILE" --group General --key rules)
  if [ -z "$existing_rules" ]; then
    kwriteconfig6 --file "$KWIN_RULES_FILE" --group General --key rules "$RULE_ID"
  else
    kwriteconfig6 --file "$KWIN_RULES_FILE" --group General --key rules "$existing_rules,$RULE_ID"
  fi
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key Description "$RULE_DESC"
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key wmclass "wl-(copy|paste)"
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key wmclassmatch 3
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key skiptaskbar --type bool "true"
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key skiptaskbarrule 2
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key skipswitcher --type bool "true"
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key skipswitcherrule 2
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key fsplevel 3
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key fsplevelrule 2
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key noborder --type bool "true"
  kwriteconfig6 --file "$KWIN_RULES_FILE" --group "$RULE_ID" --key noborderrule 2
fi

# Directories
sudo rm -f /usr/share/dbus-1/system-services/org.freedesktop.UDisks2.service
chmod 700 "${HOME}/.XDG"
touch "${HOME}/.local/share/user-places.xbel"

# Setup application DB
if [ ! -f "/etc/xdg/menus/applications.menu" ]; then
  sudo mv \
    /etc/xdg/menus/plasma-applications.menu \
    /etc/xdg/menus/applications.menu
fi
kbuildsycoca6

# Start user systemd services
if [ -d "$HOME/.config/systemd/user" ]; then
  for service_file in "$HOME/.config/systemd/user/"*.service; do
    if [ -f "$service_file" ]; then
      service_name=$(basename "$service_file")
      echo "Initializing $service_name..."
      /usr/bin/systemctl start "$service_name"
    fi
  done
fi

# Export variables globally so all children inherit them
export QT_QPA_PLATFORM=wayland
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_TYPE=wayland
export KDE_SESSION_VERSION=6
export DISPLAY=:1
export SHELL=/bin/bash
sudo mkdir -p /tmp/.X11-unix
sudo chmod 1777 /tmp/.X11-unix
dbus-run-session bash -c '
    WAYLAND_DISPLAY=wayland-1 python3 /kwin-xwayland.py &
    KWIN_PID=$!
    sleep 2
    if [ -f /usr/lib/libexec/polkit-kde-authentication-agent-1 ]; then
        /usr/lib/libexec/polkit-kde-authentication-agent-1 &
    elif [ -f /usr/libexec/polkit-kde-authentication-agent-1 ]; then
        /usr/libexec/polkit-kde-authentication-agent-1 &
    fi
    WAYLAND_DISPLAY=wayland-0 plasmashell
    kill $KWIN_PID
' > /dev/null 2>&1
