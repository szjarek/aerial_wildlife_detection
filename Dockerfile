FROM pytorch/pytorch:1.4-cuda10.1-cudnn7-devel

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=aide
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Setup basic packages, environment and user
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1 \
    #
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    && apt-get -y install git openssh-client iproute2 procps iproute2 lsb-release \
    #
    # TBC if all of this is required (from AIde scripts)
    && apt-get -y install libpq-dev python-dev wget systemd \
    #
    # Install pylint
    && /opt/conda/bin/pip install pylint \
    #
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# AIde installation starts here
# specify the root folder where you wish to install AIde
WORKDIR /home/$USERNAME/app

# create environment (requires conda or miniconda) - on the second thought, I don't need environment for docker image
# RUN conda create -y -n aide python=3.7
COPY requirements.txt requirements.txt
RUN conda install python=3.6.9 --file requirements.txt --channel defaults --channel conda-forge \
 && pip install celery[librabbitmq,redis,auth,msgpack]>=4.3.0

# Set to proper settings file
ENV PYTHONPATH=/home/${USERNAME}/app
ENV AIDE_CONFIG_PATH=/home/$USERNAME/app/config/settings.ini
ENV LOC_REGION=Europe
ENV LOC_TIMEZONE=London

# permanently (requires re-login):
# echo "export AIDE_CONFIG_PATH=path/to/settings.ini" | tee ~/.profile

# ============================ DB SERVER ONLY BEGINS ======================================
# Setup PostreSQL database
RUN ln -fs /usr/share/zoneinfo/$LOC_REGION/$LOC_TIMEZONE /etc/localtime \
# specify postgres version you wish to use (must be >= 9.5)
 && version=10 \
# install packages
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - \
 && apt-get update && sudo apt-get install -y postgresql-$version
# ============================ DB SERVER ONLY ENDS ======================================

# ============================ AI BACKEND BEGINS ========================================
# define RabbitMQ access credentials. NOTE: replace defaults with your own values
RUN sudo apt-get update && sudo apt-get install -y rabbitmq-server \
 && sudo systemctl enable rabbitmq-server.service

RUN sudo apt-get update && sudo apt-get -y install redis-server \
# make sure Redis stores its messages in an accessible folder (we're using /var/lib/redis/aide.rdb here)
 && sudo sed -i "s/^\s*dir\s*.*/dir \/var\/lib\/redis/g" /etc/redis/redis.conf \
 && sudo sed -i "s/^\s*dbfilename\s*.*/dbfilename aide.rdb/g" /etc/redis/redis.conf \
# also tell systemd
 && sudo mkdir -p /etc/systemd/system/redis.service.d \
 && echo -e "[Service]\nReadWriteDirectories=-/var/lib/redis" | sudo tee -a /etc/systemd/system/redis.service.d/override.conf > /dev/null \
 && sudo mkdir -p /var/lib/redis \
 && sudo chown -R redis:redis /var/lib/redis \
# disable persistence. In general, we don't need Redis to save snapshots as it is only used as a result
# (and therefore message) backend.
 && sudo sed -i "s/^\s*save/# save /g" /etc/redis/redis.conf \
# optional: if the port is anything else than 6379, execute the following line:
# replace with your port
 && port=6379 \
 && sudo sed -i "s/^\s*port\s*.*/port $port/g" /etc/redis/redis.conf \
# ensure only ipv4 is bound (to work properly on Docker without changing it's configuration)
 && sudo sed -i "s/^\s*bind\s*.*/bind 127.0.0.1/g" /etc/redis/redis.conf 
# ============================ AI BACKEND ENDS ==========================================

# download AIde source code (from local repository)
COPY . .
# RUN git clone git+https://github.com/szjarek/aerial_wildlife_detection.git
RUN chmod a+rwx container_setup.sh && chmod a+rwx container_start.sh

CMD bash /home/aide/app/container_start.sh \
    # Temporary command to prevent container from stopping if no command is privided
    && tail -f /dev/null
