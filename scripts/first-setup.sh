#!/bin/bash

set -ue

user="${DOCKER_USER}"
cat <<EOF
From devkit,
    Hello, ${user}!
EOF

if [ -f "/.dockerenv" ]; then
    rm /.dockerenv
fi

if pacman-key --init 2> /dev/null; then
  echo "pacman key initialized successfully."
else
  echo "Failed to initialize pacman key."
fi

# See https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/issues/3
if systemctl cancel "$(systemctl list-jobs | grep systemd-firstboot.service | awk '{print $1}')" 2> /dev/null || true; then
  echo "systemd-firstboot.service canceled successfully."
else
  echo "Failed to cancel systemd-firstboot.service."
fi

if systemctl enable --now discord.service; then
  echo "discord.service enabled and started successfully."
else
  echo "Failed to enable or start discord.service."
fi

