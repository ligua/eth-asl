import os
import fabric.api
import aslutil
import math
import msrestazure.azure_exceptions
from experiment import Experiment
from deployer import Deployer
from extractor import Extractor

# region ---- Experimental setup ----
S = 5                   # number of servers
R = 1                   # replication factor
virtual_clients_values = [144] #[1] + list(range(72, 600, 72))
num_threads_values = [32] #[1, 16, 32, 64]

experiment_runtime = 10
runtime_buffer = 15 # will be cut off when memaslaps are done
num_repetitions = 1
stats_frequency = "10s"
workload_filename = "smallvalue_nowrites.cfg"
memaslap_window_size = "1k"

combinations = []
for virtual_clients in virtual_clients_values:
    for num_threads in num_threads_values:
        for repetition in [1]: #range(num_repetitions):
            combinations.append((virtual_clients, num_threads, repetition))
#combinations = [(336, 1, 1)] # override combinations
additional_combinations = []

combinations += additional_combinations

UPDATE_AND_INSTALL = False

SKIP_IF_EXISTS = True
memaslap_summary_filename = "memaslap_stats.csv"
print("Running {} experiments with a maximum of {} minutes per experiment."
      .format(len(combinations), experiment_runtime+runtime_buffer))
estimated_mins = len(combinations) * experiment_runtime
print("Total runtime: {} hours {} minutes".format(estimated_mins // 60, estimated_mins % 60))

DRY_RUN = False

# endregion

try:
    e = Experiment()
    extractor = Extractor()

    is_first = True

    for combination in combinations:
        virtual_clients, num_threads, repetition = combination
        print("Starting experiment with {} virtual clients, {} threads, repetition {}"
                 .format(virtual_clients, num_threads, repetition))

        num_memaslaps = 1 if virtual_clients == 1 else 3
        concurrency = 1 if virtual_clients == 1 else virtual_clients / 3
        results_dir = "results/throughput/clients{}_threads{}_rep{}".format(virtual_clients, num_threads, repetition)

        experiment_already_done = os.path.isdir(results_dir)\
                                  and os.path.exists("{}/memaslap7.out".format(results_dir))\
                                  and aslutil.is_complete_memaslap_result("{}/memaslap7.out".format(results_dir))
        if SKIP_IF_EXISTS and experiment_already_done:
            print("\tComplete memaslap results exist, skipping.")
            continue

        additional_buffer = 0
        print("\tTotal buffer: {} minutes".format(additional_buffer + runtime_buffer))

        hibernate_at_end = False
        if combination == combinations[-1]: # last one
            hibernate_at_end = True

        if not DRY_RUN:
            e.start_experiment(results_dir,
                               update_and_install=UPDATE_AND_INSTALL and is_first,
                               experiment_runtime=experiment_runtime,
                               runtime_buffer=runtime_buffer,
                               stats_frequency=stats_frequency,
                               replication_factor=R,
                               num_threads_in_pool=num_threads,
                               num_memaslaps=num_memaslaps,
                               num_memcacheds=S,
                               memaslap_workload=workload_filename,
                               memaslap_window_size=memaslap_window_size,
                               hibernate_at_end=hibernate_at_end,
                               concurrency=concurrency,
                               is_first_run=is_first)

            # Extract logs
            extractor.summarise_trace_logs(logs_pattern="{}/memaslap*.out".format(results_dir),
                                           csv_path="{}/{}".format(results_dir, memaslap_summary_filename))
            # Plot graphs
            with fabric.api.settings(warn_only=True):
                fabric.api.local("Rscript scripts/r/trace.r {}".format(results_dir))

        is_first = False

    #Deployer.hibernate_wait_static("template11vms")

except msrestazure.azure_exceptions.CloudError as e:
    print("DEPLOYMENT EXCEPTION " + e.__class__.__name__ + ": " + str(e))
    if e.message.find("Unable to edit or replace deployment") == -1:
        Deployer.hibernate_wait_static("template11vms")

except Exception as e:
    print("UNKNOWN DEPLOYMENT EXCEPTION " + e.__class__.__name__ + ": " + str(e))
    Deployer.hibernate_wait_static("template11vms")
