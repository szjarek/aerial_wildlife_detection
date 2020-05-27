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
RUN conda install --file requirements.txt --channel defaults --channel conda-forge 

# download AIde source code (from local repository)
COPY . .
# RUN git clone git+https://github.com/szjarek/aerial_wildlife_detection.git

# If AIde is run on MS Azure: TCP connections are dropped after 4 minutes of inactivity
# (see https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections#idletimeout)
# This is fatal for our database connection system, which keeps connections open.
# To avoid idling/dead connections, we thus use Ubuntu's keepalive timer:
RUN bash /home/${USERNAME}/app/setupScripts/setup-keepalive.sh

# Set to proper settings file
ENV AIDE_CONFIG_PATH=/home/$USERNAME/app/config/settings.ini
ENV LOC_REGION=Europe
ENV LOC_TIMEZONE=London

# permanently (requires re-login):
# echo "export AIDE_CONFIG_PATH=path/to/settings.ini" | tee ~/.profile

# ONLY DB SERVER 
# Setup PostreSQL database
RUN ln -fs /usr/share/zoneinfo/$LOC_REGION/$LOC_TIMEZONE /etc/localtime \
 && dbName=$(python util/configDef.py --section=Database --parameter=name) \
 && dbUser=$(python util/configDef.py --section=Database --parameter=user) \
 && dbPassword=$(python util/configDef.py --section=Database --parameter=password) \
 && dbPort=$(python util/configDef.py --section=Database --parameter=port) \
# specify postgres version you wish to use (must be >= 9.5)
 && version=10 \
# install packages
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - \
 && apt-get update && sudo apt-get install -y postgresql-$version \
# update the postgres configuration with the correct port
 && sudo sed -i "s/\s*port\s*=\s[0-9]*/port = $dbPort/g" /etc/postgresql/$version/main/postgresql.conf \
# modify authentication
# NOTE: you might want to manually adapt these commands for increased security; the following makes postgres listen to all global connections
 && sudo sed -i "s/\s*#\s*listen_addresses\s=\s'localhost'/listen_addresses = '\*'/g" /etc/postgresql/$version/main/postgresql.conf \
 && echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$version/main/pg_hba.conf > /dev/null \
 && sudo service postgresql restart \
 && sudo systemctl enable postgresql \
 && sudo -u postgres psql -c "CREATE USER $dbUser WITH PASSWORD '$dbPassword';" \
 && sudo -u postgres psql -c "CREATE DATABASE $dbName WITH OWNER $dbUser CONNECTION LIMIT -1;" \
 && sudo -u postgres psql -c "GRANT CONNECT ON DATABASE $dbName TO $dbUser;" \
 && sudo -u postgres psql -d $dbName -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" \
# NOTE: needs to be run after init
 && sudo -u postgres psql -d $dbName -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $dbUser;" 
# Creating DB schema 
# && python projectCreation/setupDB.py

# Temporary entry point to prevent container from stopping if no command is privided
ENTRYPOINT ["tail", "-f", "/dev/null"]