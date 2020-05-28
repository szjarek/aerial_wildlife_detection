# Convenience function to run the frontend and AIController.
# Requires pwd to be the root of the project and the correct Python
# env to be loaded.
#
# 2019-20 Benjamin Kellenberger

# modules to run
export AIDE_MODULES=LabelUI,AIController,FileServer

# migrate AIDE (just in case)
python projectCreation/migrate_aide.py


# get host and port from configuration file
host=$(python util/configDef.py --section=Server --parameter=host)
port=$(python util/configDef.py --section=Server --parameter=port)

source ./launch_AIWorker.sh &

# HTTP server
gunicorn application:app --bind=$host:$port --workers=4

