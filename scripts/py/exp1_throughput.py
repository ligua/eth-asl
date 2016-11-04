import logging
from experiment import Experiment
from deployer import Deployer

# region ---- Logging ----
LOG_FORMAT = '%(asctime)-15s [%(name)s] - %(message)s'
LOG_LEVEL = logging.INFO
formatter = logging.Formatter(LOG_FORMAT)

ch = logging.StreamHandler()
ch.setLevel(LOG_LEVEL)
ch.setFormatter(formatter)

log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)
log.addHandler(ch)
# endregion

# region ---- Experimental setup ----
S = 5                   # number of servers
R = 1                   # replication factor
virtual_clients_values = [180] #[1] + list(range(24, 300, 24)) # [1, 24, 48, 72, 96, 120, 144, 168, 192, 216, 240, 264, 288]
num_threads_values = [1, 2] # [1, 2, 4, 8]

experiment_runtime = 10
runtime_buffer = 1
num_repetitions = 1
workload_filename = "smallvalue_nowrites.cfg"

# endregion

e = Experiment()

for virtual_clients in virtual_clients_values:
    for num_threads in num_threads_values:
        for repetition in range(num_repetitions):
            log.info("Starting experiment with {} virtual clients, {} threads, repetition {}"
                     .format(virtual_clients, num_threads, repetition))

            num_memaslaps = 1 if virtual_clients == 1 else 3
            concurrency = 1 if virtual_clients == 1 else virtual_clients / 3
            e.start_experiment("results/testing/clients{}_threads{}_rep{}".format(virtual_clients, num_threads, repetition),
                               update_and_install=False,
                               experiment_runtime=experiment_runtime,
                               runtime_buffer=runtime_buffer,
                               replication_factor=R,
                               num_threads_in_pool=num_threads,
                               num_memaslaps=num_memaslaps,
                               num_memcacheds=S,
                               hibernate_at_end=False,
                               concurrency=concurrency)

Deployer.hibernate_wait_static("template11vms")

# TODO catch any exception and do a force hibernate if exception


