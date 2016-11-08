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
virtual_clients_values = [336, 384] #[1] + list(range(48, 300, 48))
num_threads_values = [1, 16, 32, 64]

experiment_runtime = 10
runtime_buffer = 30 # will be cut off when memaslaps are done
num_repetitions = 1
workload_filename = "smallvalue_nowrites.cfg"

combinations = []
for virtual_clients in virtual_clients_values:
    for num_threads in num_threads_values:
        for repetition in range(num_repetitions):
            combinations.append((virtual_clients, num_threads, repetition))
#combinations = [(3, 1, 1)] # override combinations

SKIP_IF_EXISTS = True
memaslap_summary_filename = "memaslap_stats.csv"
print("Running {} experiments with a maximum of {} minutes per experiment."
      .format(len(combinations), experiment_runtime+runtime_buffer))

# endregion

def extra_buffer(num_clients, num_threads):
    buf = (num_threads) * (1 + num_clients / 100)
    return 0 if buf < 1 else math.ceil(buf)

try:
    e = Experiment()
    extractor = Extractor()

    for virtual_clients, num_threads, repetition in combinations:
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

        additional_buffer = extra_buffer(virtual_clients, num_threads)
        print("\tTotal buffer: {} minutes".format(additional_buffer + runtime_buffer))

        hibernate_at_end = False
        if (virtual_clients, num_threads, repetition) == combinations[-1]: # last one
            hibernate_at_end = True

        e.start_experiment(results_dir,
                           update_and_install=False,
                           experiment_runtime=experiment_runtime,
                           runtime_buffer=runtime_buffer,
                           replication_factor=R,
                           num_threads_in_pool=num_threads,
                           num_memaslaps=num_memaslaps,
                           num_memcacheds=S,
                           memaslap_workload=workload_filename,
                           hibernate_at_end=hibernate_at_end,
                           concurrency=concurrency)

        # Extract logs
        extractor.summarise_trace_logs(logs_pattern="{}/memaslap*.out".format(results_dir),
                                       csv_path="{}/{}".format(results_dir, memaslap_summary_filename))
        # Plot graphs
        with fabric.api.settings(warn_only=True):
            fabric.api.local("Rscript scripts/r/trace.r {}".format(results_dir))

    #Deployer.hibernate_wait_static("template11vms")

except msrestazure.azure_exceptions.CloudError as e:
    print("DEPLOYMENT EXCEPTION " + e.__class__.__name__ + ": " + str(e))
    if e.message.find("Unable to edit or replace deployment") == -1:
        Deployer.hibernate_wait_static("template11vms")

except Exception as e:
    print("UNKNOWN DEPLOYMENT EXCEPTION " + e.__class__.__name__ + ": " + str(e))
    Deployer.hibernate_wait_static("template11vms")
