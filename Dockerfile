# syntax = docker/dockerfile:1.2

FROM archlinux

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

RUN cat /etc/pacman.d/mirrorlist | cat <(curl -s "https://archlinux.org/mirrorlist/?country=JP" | sed -e 's/^#Server/Server/') - > /etc/pacman.d/mirrorlist
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
    systemd \
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
RUN echo "${DOCKER_USER} ALL=(ALL) ALL" >> /etc/sudoers
RUN mkdir -p /home/${DOCKER_USER}/work
RUN chown -R ${DOCKER_USER}:${DOCKER_USER} /home/${DOCKER_USER}

# wsl2
COPY wsl.conf /etc/wsl.conf
RUN sed -i "s/\${DOCKER_USER}/${DOCKER_USER}/g" /etc/wsl.conf

USER ${DOCKER_USER}
WORKDIR /home/${DOCKER_USER}/work

CMD ["bash"]
