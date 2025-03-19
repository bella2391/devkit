# syntax = docker/dockerfile:1.2

FROM archlinux:latest

ARG DOCKER_USER_ID=1000
ARG DOCKER_USER
ARG DOCKER_USER_PASSWD
ARG DOCKER_GROUP

ENV DOCKER_USER=${DOCKER_USER}
ENV DOCKER_USER_PASSWD=${DOCKER_USER_PASSWD}
ENV DOCKER_GROUP=${DOCKER_GROUP}

RUN echo "DOCKER_USER: ${DOCKER_USER}"

RUN sed -i -e 's|^\(NoExtract *= *usr/share/man/\)|#\1|' /etc/pacman.conf

# required base packages
RUN pacman-key --init

RUN curl -s "https://archlinux.org/mirrorlist/?country=JP" | sed -e 's/^#Server/Server/' >> /etc/pacman.d/mirrorlist
RUN sed -i '/^#Server = https:\/\/.*\.jp\/.*$/s/^#//' /etc/pacman.d/mirrorlist

RUN pacman -Syyu --noconfirm && \
    pacman -Sy --noconfirm \
    base base-devel \
    bash bash-completion \
    sudo \
    man-db man-pages \
    coreutils \
    gzip which less wget binutils \
    vim \
    git \
    systemd systemd-sysvcompat \
    && \
    pacman -Scc && \
    rm -rf /var/cache/pacman/*

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
    find /app/config /app/scripts -type f -exec sh -c 'iconv -f WINDOWS-1252 -t UTF-8 "$1" -o "$1.utf8" && mv "$1.utf8" "$1" && dos2unix "$1"' -- {} \; && \
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

USER ${DOCKER_USER}
WORKDIR /home/${DOCKER_USER}/work

RUN sudo pacman -Sy --noconfirm \
    kitty starship w3m lazygit tree unzip neovim

ENV container=docker

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]

