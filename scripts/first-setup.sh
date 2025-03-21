#!/bin/bash

set -ue

user="${DOCKER_USER}"
cat <<EOF
From devkit,
    Hello, ${user}!
EOF

rm /.dockerenv
echo -e "\nGenerating pacman lsign key..." && pacman-key --init 2> /dev/null && echo "Done"

# See https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/issues/3
systemctl cancel "$(systemctl list-jobs | grep systemd-firstboot.service | awk '{print $1}')" 2> /dev/null || true

# Git config
while true; do
  read -p "Enter your github email address: " email
  if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    break
  else
    echo "Invalid email address. Please try again."
  fi
done

read -p "Enter your github name: " name

git config --global user.email "$email"
git config --global user.name "$name"

echo "Git configuration completed."

