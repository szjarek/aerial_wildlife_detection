#!/bin/bash

FILE=/home/aide/files/setup_complete.txt

if [ -f "$FILE" ]; then
    echo "SETUP ALREADY COMPLETED"
else
# =================================
# = FIRST TIME SETUP POSTGRESS DB =
# =================================
    dbName=$(python util/configDef.py --section=Database --parameter=name)
    dbUser=$(python util/configDef.py --section=Database --parameter=user)
    dbPassword=$(python util/configDef.py --section=Database --parameter=password)
    dbPort=$(python util/configDef.py --section=Database --parameter=port)
# specify postgres version you wish to use (must be >= 9.5)
    version=10
# update the postgres configuration with the correct port
    sudo sed -i "s/\s*port\s*=\s[0-9]*/port = $dbPort/g" /etc/postgresql/$version/main/postgresql.conf 
# modify authentication
# NOTE: you might want to manually adapt these commands for increased security; the following makes postgres listen to all global connections
    sudo sed -i "s/\s*#\s*listen_addresses\s=\s'localhost'/listen_addresses = '\*'/g" /etc/postgresql/$version/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$version/main/pg_hba.conf > /dev/null
    sudo service postgresql restart
    sudo systemctl enable postgresql
    sudo -u postgres psql -c "CREATE USER $dbUser WITH PASSWORD '$dbPassword';"
    sudo -u postgres psql -c "CREATE DATABASE $dbName WITH OWNER $dbUser CONNECTION LIMIT -1;"
    sudo -u postgres psql -c "GRANT CONNECT ON DATABASE $dbName TO $dbUser;"
    sudo -u postgres psql -d $dbName -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
# NOTE: needs to be run after init
    sudo -u postgres psql -d $dbName -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $dbUser;"
# Create DB schema
    python projectCreation/setupDB.py

# =================================
# =   FIRST TIME SETUP RABBITMQ   =
# =================================
    # I need to set rabitmq user and permissions here, as it takes hostname (dynamic) during build of previous phases as part of config folder :-()
    RMQ_username=aide
    RMQ_password=password # This should never be left here for any serious use of course
    sudo service rabbitmq-server start
    # add the user we defined above
    sudo rabbitmqctl add_user $RMQ_username $RMQ_password
    # add new virtual host
    sudo rabbitmqctl add_vhost aide_vhost
    # set permissions
    sudo rabbitmqctl set_permissions -p aide_vhost $RMQ_username ".*" ".*" ".*"

    # Create file to avoid running this script again
    touch $FILE
    echo "FIRST TIME SETUP COMPLETED"
fi
