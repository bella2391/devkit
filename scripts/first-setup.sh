#!/bin/bash

echo "Hello!"
echo -e "\nGenerating pacman lsign key..." && pacman-key --init 2> /dev/null && echo "Done"

# See https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/issues/3
systemctl cancel "$(systemctl list-jobs | grep systemd-firstboot.service | awk '{print $1}')" 2> /dev/null || true
