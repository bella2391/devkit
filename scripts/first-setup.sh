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

# Git setup prompt
read -p "Do you setup github config? (require login in your browser) (y/n): " setup_github
if [[ "$setup_github" == "y" ]]; then
  # while true; do
  #   read -p "Enter your github email address: " email
  #   if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  #     break
  #   else
  #     echo "Invalid email address. Please try again."
  #   fi
  # done

  # read -p "Enter your github name: " name

  # sudo -u "$user" git config --global user.email "$email"
  # sudo -u "$user" git config --global user.name "$name"

  if [ ! -L /run/user/1000/wayland-0 ]; then
    if [ -d /mnt/wslg/runtime-dir ]; then
      sudo -u "$user" ln -s /mnt/wslg/runtime-dir/wayland-0* /run/user/1000/
      echo "\[$(date '+%Y-%m-%d %H:%M:%S')\] CREATED WAYLAND SYMLINK FROM FIRST-SETUP" >> $HOME/.wsl.log
    else
      echo "Error: /mnt/wslg/runtime-dir not found."
    fi
  fi

  sudo -u "$user" git-credential-manager github login --no-ui
  echo "Git configuration completed."
else
    echo "Github setup skipped."
fi

