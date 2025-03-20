# syntax = docker/dockerfile:1.2

FROM archlinux:latest

ARG DOCKER_USER_ID=1000
ARG DOCKER_USER
ARG DOCKER_USER_PASSWD
ARG DOCKER_GROUP

ENV DOCKER_USER=${DOCKER_USER}
ENV DOCKER_USER_PASSWD=${DOCKER_USER_PASSWD}
ENV DOCKER_GROUP=${DOCKER_GROUP}

RUN pacman-key --init >> /dev/null

RUN curl -s "https://archlinux.org/mirrorlist/?country=JP" | sed -e 's/^#Server/Server/' >> /etc/pacman.d/mirrorlist
RUN sed -i '/^#Server = https:\/\/.*\.jp\/.*$/s/^#//' /etc/pacman.d/mirrorlist

RUN pacman -Syyu --noconfirm && \
    pacman -Sy --noconfirm \
    base base-devel \
    bash bash-completion \
    sudo \
    man-db man-pages \
    coreutils \
    gzip unzip tree which less wget binutils parallel \
    gvim \
    git \
    systemd systemd-sysvcompat \
    && \
    pacman -Scc

# locale
RUN echo LANG=en_US.UTF-8 > /etc/locale.conf && \
    echo "en_US.UTF-8 UTF-8" | tee -a /etc/locale.gen && \
    locale-gen

# timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone

# user
RUN if ! grep -q "^${DOCKER_GROUP}:" /etc/group; then \
        groupadd "${DOCKER_GROUP}"; \
    fi
RUN useradd -m -s /bin/bash -u ${DOCKER_USER_ID} -G ${DOCKER_GROUP} ${DOCKER_USER}
RUN echo "${DOCKER_USER}:${DOCKER_USER_PASSWD}" | chpasswd
RUN echo "${DOCKER_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN mkdir -p /home/${DOCKER_USER}/work
RUN chown -R ${DOCKER_USER}:${DOCKER_USER} /home/${DOCKER_USER}

RUN mkdir -p /etc/systemd/system/getty@tty1.service.d && \
    echo "[Service]\nExecStart=\nExecStart=-/sbin/agetty --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/override.conf

# WSL2
WORKDIR /app
COPY . /app/

RUN pacman -Sy --noconfirm dos2unix && \
    find /app/config /app/scripts -type f -exec sh -c 'iconv -f WINDOWS-1252 -t UTF-8 "$1" -o "$1.utf8" && mv "$1.utf8" "$1" && dos2unix "$1"' -- {} \; >> /dev/null 2>&1 && \
    sed -i "s/\${DOCKER_USER}/${DOCKER_USER}/g" /app/config/wsl.conf && \
    chmod 644 /app/config/wsl.conf && \
    chmod 644 /app/config/wsl-distribution.conf && \
    chmod +x /app/scripts/first-setup.sh

RUN mkdir -p /usr/lib/wsl/ && \
    cp /app/config/wsl.conf /etc/wsl.conf && \
    cp /app/config/wsl-distribution.conf /etc/wsl-distribution.conf && \
    cp /app/config/terminal-profile.json /usr/lib/wsl/terminal-profile.json && \
    cp /app/assets/archlinux.ico /usr/lib/wsl/archlinux.ico && \
    cp /app/scripts/first-setup.sh /usr/lib/wsl/first-setup.sh

# create development for programming
USER ${DOCKER_USER}
WORKDIR /home/${DOCKER_USER}/work

RUN sudo pacman -Sy --noconfirm \
    kitty imagemagick starship w3m lazygit neovim firefox

# yay
RUN sudo pacman -Sy --noconfirm go && \
    git clone https://aur.archlinux.org/yay.git && \
    cd yay && \
    makepkg --noconfirm -si && \
    yay -Syyu --noconfirm

# fonts
RUN mkdir -p ~/.local/share/fonts && \
    wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Agave.zip && \
    unzip Agave.zip -d ~/.local/share/fonts/ && \
    fc-cache -fv

# dotfiles
RUN git clone https://github.com/bella2391/dotfiles.git && \
    cd dotfiles && \
    # find . -mindepth 1 -maxdepth 1 -exec mv -t ~ {} + && \
    find . -mindepth 1 ! -path "./.config*" -maxdepth 1 -exec mv -t ~ {} + && \
    cd .config && \
    find . -mindepth 1 -maxdepth 1 -exec mv -t ~/.config/ {} + && \
    cd ~ && \
    git submodule update --init --recursive && \
    source ~/.bashrc >> /dev/null

# win32yank for wsl
RUN wget https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip && \
    unzip win32yank-x64.zip -d ~/.global/bin/ && \
    rm ~/.global/bin/README.md ~/.global/bin/LICENSE && \
    chmod +x ~/.global/bin/win32yank.exe

# rustup/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >> /dev/null 2>&1

# pyenv
RUN sudo pacman -Sy --noconfirm tk && \
    curl -fsSL https://pyenv.run | bash >> /dev/null 2>&1 && \
    pyenv install 3.13.2 >> /dev/null 2>&1 && \
    pyenv global 3.13.2

# docker
# RUN sudo pacman -Sy --noconfirm docker docker-compose

# import bella, my repositories
RUN mkdir -p ~/git/ && \
    cd ~/git/ && \
    parallel 'git clone https://github.com/bella2391/{}.git' ::: FMC FMCWebApp && \
    mkdir -p Learning && \
    cd Learning && \
    parallel 'git clone -b {} https://github.com/bella2391/Learning.git {}' ::: c js/ts master python rust scala

# github-credential-manager
RUN yay -S --noconfirm git-credential-manager-core-extras && \
    git config --global credential.helper 'manager' && \
    git config --global credential.credentialStore secretservice

# scala
RUN curl -s "https://get.sdkman.io" | bash && \
    sdk install java $(sdk list java | grep -o "\b8\.[0-9]*\.[0-9]*\-tem" | head -1) && \
    sdk install sbt && \
    # sdk install java 17.0.12-oracle && \
    yay -S --noconfirm coursier && \
    cs install metals

USER root

ENV container=docker

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]

