import fabric.api
import msrestazure.azure_exceptions
from experiment import Experiment
from deployer import Deployer
from extractor import Extractor

# region ---- Experimental setup ----
S = 5                   # number of servers
R = 1                   # replication factor
virtual_clients_values = [1] + list(range(48, 240, 48))
num_threads_values = [1, 2, 4, 8]

experiment_runtime = 10
runtime_buffer = 1
num_repetitions = 1
workload_filename = "smallvalue_nowrites.cfg"

# endregion

try:
    e = Experiment()
    extractor = Extractor()

    for virtual_clients in virtual_clients_values:
        for num_threads in num_threads_values:
            for repetition in range(num_repetitions):
                print("Starting experiment with {} virtual clients, {} threads, repetition {}"
                         .format(virtual_clients, num_threads, repetition))

                num_memaslaps = 1 if virtual_clients == 1 else 3
                concurrency = 1 if virtual_clients == 1 else virtual_clients / 3
                results_dir = "results/throughput/clients{}_threads{}_rep{}".format(virtual_clients, num_threads, repetition)
                e.start_experiment(results_dir,
                                   update_and_install=False,
                                   experiment_runtime=experiment_runtime,
                                   runtime_buffer=runtime_buffer,
                                   replication_factor=R,
                                   num_threads_in_pool=num_threads,
                                   num_memaslaps=num_memaslaps,
                                   num_memcacheds=S,
                                   memaslap_workload=workload_filename,
                                   hibernate_at_end=False,
                                   concurrency=concurrency)

                # Extract logs
                extractor.summarise_trace_logs(logs_pattern="{}/memaslap*.out".format(results_dir),
                                               csv_path="{}/memaslap_stats.csv".format(results_dir))
                # Plot graphs
                with fabric.api.settings(warn_only=True):
                    fabric.api.local("Rscript scripts/r/trace.r {}".format(results_dir))

    Deployer.hibernate_wait_static("template11vms")

except msrestazure.azure_exceptions.CloudError as e:
    print("DEPLOYMENT EXCEPTION " + e.__class__.__name__ + ": " + str(e))
    if e.message.find("Unable to edit or replace deployment") == -1:
        Deployer.hibernate_wait_static("template11vms")


except Exception as e:
    print("DEPLOYMENT EXCEPTION " + e.__class__.__name__ + ": " + str(e))
    Deployer.hibernate_wait_static("template11vms")