# syntax = docker/dockerfile:1.2

FROM archlinux:latest

ARG DOCKER_USER_ID=1000
ARG DOCKER_USER
ARG DOCKER_USER_PASSWD
ARG DOCKER_GROUP

ENV DOCKER_USER=${DOCKER_USER}
ENV DOCKER_USER_PASSWD=${DOCKER_USER_PASSWD}
ENV DOCKER_GROUP=${DOCKER_GROUP}

RUN curl -s "https://archlinux.org/mirrorlist/?country=JP" | sed -e 's/^#Server/Server/' >> /etc/pacman.d/mirrorlist && \
    sed -i '/^#Server = https:\/\/.*\.jp\/.*$/s/^#//' /etc/pacman.d/mirrorlist && \
    sed -i -e 's|^\(NoExtract *= *usr/share/man/\)|#\1|' /etc/pacman.conf

RUN pacman-key --init >> /dev/null && \
    pacman -Syyu --noconfirm && \
    pacman -Sy --noconfirm \
    base base-devel \
    bash bash-completion \
    sudo \
    man-db man-pages \
    coreutils \
    gzip unzip zip tree which less wget binutils parallel \
    gvim \
    git \
    systemd \
    systemd-sysvcompat \
    && \
    pacman -Scc

# Locale
RUN echo LANG=en_US.UTF-8 > /etc/locale.conf && \
    echo "en_US.UTF-8 UTF-8" | tee -a /etc/locale.gen && \
    locale-gen

# Timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone

# User
RUN if ! grep -q "^${DOCKER_GROUP}:" /etc/group; then \
        groupadd "${DOCKER_GROUP}"; \
    fi && \
    useradd -m -s /bin/bash -u ${DOCKER_USER_ID} -G ${DOCKER_GROUP} ${DOCKER_USER} && \
    echo "${DOCKER_USER}:${DOCKER_USER_PASSWD}" | chpasswd && \
    echo "${DOCKER_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    mkdir -p /home/${DOCKER_USER}/work && \
    chown -R ${DOCKER_USER}:${DOCKER_USER} /home/${DOCKER_USER}

# WSL2
WORKDIR /app
COPY . /app/

RUN pacman -Sy --noconfirm dos2unix && \
    find config scripts -type f -exec sh -c 'iconv -f WINDOWS-1252 -t UTF-8 "$1" -o "$1.utf8" && mv "$1.utf8" "$1" && dos2unix "$1"' -- {} \; >> /dev/null 2>&1 && \
    sed -i "s/\${DOCKER_USER}/${DOCKER_USER}/g" config/wsl.conf && \
    sed -i "s/\${DOCKER_USER}/${DOCKER_USER}/g" scripts/first-setup.sh && \
    chmod 644 config/wsl.conf && \
    chmod 644 config/wsl-distribution.conf && \
    chmod +x scripts/first-setup.sh && \
    mkdir -p /usr/lib/wsl/ && \
    cp config/wsl.conf /etc/wsl.conf && \
    cp config/wsl-distribution.conf /etc/wsl-distribution.conf && \
    cp config/terminal-profile.json /usr/lib/wsl/terminal-profile.json && \
    cp assets/archlinux.ico /usr/lib/wsl/archlinux.ico && \
    cp scripts/first-setup.sh /usr/lib/wsl/first-setup.sh

RUN mkdir -p /etc/tmpfiles.d && \
    echo "L+ /tmp/.X11-unix - - - - /mnt/wslg/.X11-unix" > /etc/tmpfiles.d/wslg.conf

# create development for programming
USER ${DOCKER_USER}
WORKDIR /home/${DOCKER_USER}/work

RUN sudo pacman -Sy --noconfirm \
    kitty imagemagick starship w3m lazygit neovim firefox

# dotfiles
RUN git clone https://github.com/bella2391/dotfiles.git && \
    cd dotfiles && \
    find . -mindepth 1 ! -path "./.config*" -maxdepth 1 -exec mv -t ~ {} + && \
    cd .config && \
    mkdir -p ~/.config/ && \
    find . -mindepth 1 -maxdepth 1 -exec mv -t ~/.config/ {} + && \
    cd ~ && \
    git submodule update --init --recursive

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

# win32yank for wsl
RUN wget https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip && \
    unzip win32yank-x64.zip -d ~/.global/bin/ && \
    rm ~/.global/bin/README.md ~/.global/bin/LICENSE && \
    chmod +x ~/.global/bin/win32yank.exe

# rustup/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >> /dev/null 2>&1

# pyenv
RUN sudo pacman -Sy --noconfirm tk pyenv && \
    export PYENV_ROOT="$HOME/.pyenv" && \
    export PATH="$PYENV_ROOT/bin:$PATH" && \
    eval "$(pyenv init --path)" && \
    eval "$(pyenv init -)" && \
    eval "$(pyenv virtualenv-init -)" && \
    pyenv install 3.13.2 >> /dev/null 2>&1 && \
    pyenv global 3.13.2

# java (using sdkman)
RUN if [ ! -s "~/.sdkman/bin/sdkman-init.sh" ]; then curl -s "https://get.sdkman.io" | bash; fi && \
    source ~/.sdkman/bin/sdkman-init.sh && \
    export SDKMAN_AUTO_ANSWER=true && \
    if command -v sdk &> /dev/null; then \
        sdk install java 17.0.12-oracle; \
    fi

# scala (require sdkman)
RUN if [ ! -s "~/.sdkman/bin/sdkman-init.sh" ]; then curl -s "https://get.sdkman.io" | bash; fi && \
    source ~/.sdkman/bin/sdkman-init.sh && \
    export SDKMAN_AUTO_ANSWER=true && \
    if command -v sdk &> /dev/null; then \
        sdk install sbt && \
        yay -S --noconfirm coursier && \
        coursier setup -y && \
        coursier install metals; \
    fi

# nvm/npm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" && \
    nvm install 22.12.0

