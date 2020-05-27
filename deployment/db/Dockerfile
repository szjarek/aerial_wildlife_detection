FROM postgres:10

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

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
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# download AIde source code (from local repository)
COPY . .

# If AIde is run on MS Azure: TCP connections are dropped after 4 minutes of inactivity
# (see https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections#idletimeout)
# This is fatal for our database connection system, which keeps connections open.
# To avoid idling/dead connections, we thus use Ubuntu's keepalive timer:
# RUN bash ./setupScripts/setup-keepalive.sh

# Set to proper settings file
ENV PYTHONPATH=.
ENV AIDE_CONFIG_PATH=./config/settings.ini

# ============================ DB SERVER ONLY BEGINS ======================================
# Setup PostreSQL database
#RUN dbName=$(python util/configDef.py --section=Database --parameter=name) \
# && dbUser=$(python util/configDef.py --section=Database --parameter=user) \
# && dbPassword=$(python util/configDef.py --section=Database --parameter=password) \
# && dbPort=$(python util/configDef.py --section=Database --parameter=port) \
# specify postgres version you wish to use (must be >= 9.5)
# && version=10 \
# update the postgres configuration with the correct port
# && sudo sed -i "s/\s*port\s*=\s[0-9]*/port = $dbPort/g" /etc/postgresql/$version/main/postgresql.conf \
# modify authentication
#NOTE: you might want to manually adapt these commands for increased security; the following makes postgres listen to all global connections
# && sudo sed -i "s/\s*#\s*listen_addresses\s=\s'localhost'/listen_addresses = '\*'/g" /etc/postgresql/$version/main/postgresql.conf \
# && echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$version/main/pg_hba.conf > /dev/null \
# && sudo service postgresql restart \
# && sudo systemctl enable postgresql \
# && sudo -u postgres psql -c "CREATE USER $dbUser WITH PASSWORD '$dbPassword';" \
# && sudo -u postgres psql -c "CREATE DATABASE $dbName WITH OWNER $dbUser CONNECTION LIMIT -1;" \
# && sudo -u postgres psql -c "GRANT CONNECT ON DATABASE $dbName TO $dbUser;" \
# && sudo -u postgres psql -d $dbName -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" \
# NOTE: needs to be run after init
# && sudo -u postgres psql -d $dbName -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $dbUser;" \
# Create DB schema
# && python projectCreation/setupDB.py
# ============================ DB SERVER ONLY ENDS ======================================

# Temporary entry point to prevent container from stopping if no command is privided
ENTRYPOINT ["tail", "-f", "/dev/null"]