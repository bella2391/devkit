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

echo -e "\nGenerating pacman lsign key..." && pacman-key --init 2> /dev/null && echo -e "Done\n"

# See https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/issues/3
systemctl cancel "$(systemctl list-jobs | grep systemd-firstboot.service | awk '{print $1}')" 2> /dev/null || true

