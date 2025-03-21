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

echo -e "\nGenerating pacman lsign key..." && pacman-key --init 2> /dev/null && echo "Done\n"

# See https://gitlab.archlinux.org/archlinux/archlinux-wsl/-/issues/3
systemctl cancel "$(systemctl list-jobs | grep systemd-firstboot.service | awk '{print $1}')" 2> /dev/null || true

# Git setup prompt
read -p "Do you setup github config? (y/n): " setup_github
if [[ "$setup_github" == "y" ]]; then
  while true; do
    read -p "Enter your github email address: " email
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      break
    else
      echo "Invalid email address. Please try again."
    fi
  done

  read -p "Enter your github name: " name

  sudo -u "$user" git config --global user.email "$email"
  sudo -u "$user" git config --global user.name "$name"

  echo "Git configuration completed."
else
    echo "Github setup skipped."
fi

