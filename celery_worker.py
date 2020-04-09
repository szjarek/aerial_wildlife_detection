'''
    Sets up the appropriate Celery consumer(s):
    - AIController
    - AIWorker
    - DataManagement

    depending on the "AIDE_MODULES" environment
    variable.

    2020 Benjamin Kellenberger
'''

import os
from celery import Celery
from kombu import Queue
from kombu.common import Broadcast
from util.configDef import Config

# force enable passive mode
os.environ['PASSIVE_MODE'] = '1'

# parse system config
if not 'AIDE_CONFIG_PATH' in os.environ:
    raise ValueError('Missing system environment variable "AIDE_CONFIG_PATH".')
if not 'AIDE_MODULES' in os.environ:
    raise ValueError('Missing system environment variable "AIDE_MODULES".')
config = Config()


aide_modules = os.environ['AIDE_MODULES'].split(',')
aide_modules = set([a.strip().lower() for a in aide_modules])

queues = [Broadcast('aide_broadcast')]
if 'aicontroller' in aide_modules:
    queues.append(Queue('AIController'))
if 'aiworker' in aide_modules:
    queues.append(Queue('AIWorker'))
if 'fileserver' in aide_modules:
    queues.append(Queue('FileServer'))


app = Celery('AIDE',
            broker=config.getProperty('AIController', 'broker_URL'),        #TODO
            backend=config.getProperty('AIController', 'result_backend'))   #TODO
app.conf.update(
    result_backend=config.getProperty('AIController', 'result_backend'),    #TODO
    task_ignore_result=False,
    result_persistent=True,
    accept_content = ['json'],
    task_serializer = 'json',
    result_serializer = 'json',
    task_track_started = True,
    broker_pool_limit=None,                 # required to avoid peer connection resets
    broker_heartbeat = 0,                   # required to avoid peer connection resets
    worker_max_tasks_per_child = 1,         # required to free memory (also CUDA) after each process
    task_default_rate_limit = 3,            #TODO
    worker_prefetch_multiplier = 1,         #TODO
    task_acks_late = True,
    task_create_missing_queues = False,
    task_queues = tuple(queues),
    task_routes = {
        'aide_admin': {
            'queue': 'aide_broadcast',
            'exchange': 'aide_broadcast'
        }
    }
    #task_default_queue = Broadcast('aide_admin')
)


# initialize appropriate consumer functionalities
num_modules = 0
if 'aicontroller' in aide_modules:
    from modules.AIController.backend import celery_interface as aic_int
    aic_int.aide_internal_notify({'task': 'add_projects'})
    num_modules += 1
if 'aiworker' in aide_modules:
    from modules.AIWorker.backend import celery_interface as aiw_int
    aiw_int.aide_internal_notify({'task': 'add_projects'})
    num_modules += 1
if 'fileserver' in aide_modules:
    from modules.DataAdministration.backend import celery_interface as da_int
    da_int.aide_internal_notify({'task': 'add_projects'})
    num_modules += 1



if __name__ == '__main__':
    # launch Celery consumer
    if num_modules:
        app.start()