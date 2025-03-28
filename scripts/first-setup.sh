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

if pacman-key --init 2>/dev/null; then
  echo -e "\npacman key initialized successfully."
else
  echo -e "\nFailed to initialize pacman key."
fi

# See https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/issues/3
if systemctl cancel "$(systemctl list-jobs | grep systemd-firstboot.service | awk '{print $1}')" 2>/dev/null || true; then
  echo -e "\nsystemd-firstboot.service canceled successfully."
else
  echo -e "\nFailed to cancel systemd-firstboot.service."
fi

if systemctl enable --now discord.service 2>/dev/null; then
  echo -e "\ndiscord.service enabled and started successfully."
else
  echo -e "\nFailed to enable or start discord.service."
fi
