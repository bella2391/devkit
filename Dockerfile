# syntax = docker/dockerfile:1.2

FROM archlinux

ARG DOCKER_USER
ARG DOCKER_USER_ID=1000
ARG DOCKER_GROUP=users2

ENV DOCKER_USER=${DOCKER_USER}
ENV DOCKER_USER_ID=${DOCKER_USER_ID}
ENV DOCKER_GROUP=${DOCKER_GROUP}
ENV LANG=ja_JP.UTF-8
ENV LANGUAGE=ja_JP:ja
ENV LC_ALL=ja_JP.UTF-8

# required base packages
RUN pacman -Syu --noconfirm --needed base base-devel git vim wget curl sudo coreutils

# locale
RUN echo LANG=en_US.UTF-8 > /etc/locale.conf && \
    tee -a /etc/locale.gen <<EOL \
    ja_JP.UTF-8 UTF-8 \
    en_US.UTF-8 UTF-8 \
    EOL && \
    locale-gen

# timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone

# user
RUN groupadd "${DOCKER_GROUP}"
RUN useradd -m -u ${DOCKER_USER_ID} -G ${DOCKER_GROUP} ${DOCKER_USER}
RUN echo "%${DOCKER_USER} ALL=(ALL) ALL" >> /etc/sudoers
RUN mkdir -p /home/${DOCKER_USER}/work
RUN chown -R ${DOCKER_USER}:${DOCKER_USER} /home/${DOCKER_USER}

# wsl2
COPY wsl.conf /etc/wsl.conf

USER ${DOCKER_USER}
WORKDIR /home/${DOCKER_USER}/work

CMD ["bash"]
