import os.path
import logging
import time
import fabric.api
from memaslap import Memaslap
from memcached import Memcached

from colors import Colors
from deployer import Deployer

UPDATE_AND_INSTALL = False
NUM_REPETITIONS = 5
EXPERIMENT_RUNTIME = 60  # seconds
EXPERIMENT_RUNTIME_STRING = "{}s".format(EXPERIMENT_RUNTIME)
STATS_FREQUENCY = "30s"
MEMASLAP_WORKLOAD = "smallvalue.cfg"

results_dir = "results/baseline"
with fabric.api.settings(warn_only=True):
    fabric.api.local("rm -r {}/*".format(results_dir))
    fabric.api.local("mkdir -p {}".format(results_dir))

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

# region ---- Parameters ----
resource_group_name = 'template3vms'
my_pub_ssh_key_path = '~/.ssh/id_rsa_asl.pub'
template_path = "azure-templates/template3vms.json"
dns_label_prefix = "pungast"
virtual_network_name = "MyVNet"

pub_ssh_key_path = os.path.expanduser(my_pub_ssh_key_path)
with open(pub_ssh_key_path, 'r') as pub_ssh_file_fd:
    pub_ssh_key = pub_ssh_file_fd.read().strip()

parameters = {
    "virtualMachines_name": "foraslvms",
    "virtualMachines_adminPassword": "U6Mh=be:vma+&>R'pcMwFVls?=",
    "networkInterfaces_name": "MyNetworkInterface",
    "virtualNetworks_testeth_vnet_name": virtual_network_name,
    "key": pub_ssh_key,
    "uniquedns": dns_label_prefix
}
# endregion

# Initialize the deployer class
deployer = Deployer(resource_group_name, template_path, parameters)
deployer.deploy_wait()

# region ---- Extract VMs' IPs ----
vms = deployer.compute_client.virtual_machines.list(resource_group_name)
vm_names = []
public_hostnames = []
private_hostnames = []

for vm in vms:
    log.info("VM {}".format(Colors.ok_blue(vm.name)))
    # Get machine's public address that we can use for SSH-ing
    public_ip = deployer.network_client.public_ip_addresses.get(resource_group_name, vm.name)
    public_host_address = public_ip.dns_settings.fqdn
    public_hostnames.append(public_host_address)
    log.info("Public host name: {}".format(Colors.ok_green(public_host_address)))

    # Get machine's private IP address
    network_interface_id = vm.network_profile.network_interfaces[0].id
    network_interface_name = network_interface_id.split("/")[-1]
    network_interface = deployer.network_client.network_interfaces.get(resource_group_name, network_interface_name)
    private_host_address = network_interface.ip_configurations[0].private_ip_address
    private_hostnames.append(private_host_address)
    log.info("Private host name: {}".format(Colors.ok_green(private_host_address)))

# endregion

# region ---- Setup memcached and memaslap ----
memcached_serve_address = private_hostnames[0]
memcached_port = 11211
memcached_server = Memcached(memcached_port, public_hostnames[0])
memaslap_server1 = Memaslap(public_hostnames[1], memcached_serve_address, memcached_port)
memaslap_server2 = Memaslap(public_hostnames[2], memcached_serve_address, memcached_port)

if UPDATE_AND_INSTALL:
    memcached_server.update_and_install()
    memaslap_server1.update_and_install()
    memaslap_server2.update_and_install()

# endregion

# region ---- Experiment ----
# Clear logs
memaslap_server1.clear_logs()
memaslap_server2.clear_logs()

log_filename_base = "baseline_memaslap{}_conc{:03}_rep{:02}.out"
ms_concurrencies = [1, 2, 4] + list(range(8, 129, 8))
log.info("Running {} repetitions each at concurrencies {}".format(NUM_REPETITIONS, str(ms_concurrencies)))

for i in range(0, len(ms_concurrencies)):
    for rep in range(NUM_REPETITIONS):
        log.info("Starting experiment at concurrency {}, repetition {}.".format(ms_concurrencies[i], rep))
        memcached_server.start()
        time.sleep(1)

        # There should be just one client if concurrency=1, otherwise two clients
        concurrency_per_client = ms_concurrencies[i]
        if concurrency_per_client == 1:
            concurrency_per_client = 1
        else:
            concurrency_per_client = int(concurrency_per_client / 2)

        memaslap_server1.start(concurrency=concurrency_per_client, runtime=EXPERIMENT_RUNTIME_STRING,
                               stats_freq=STATS_FREQUENCY, workload_filename=MEMASLAP_WORKLOAD,
                               log_filename=log_filename_base.format(1, ms_concurrencies[i], rep))
        if ms_concurrencies[i] > 1:
            memaslap_server2.start(concurrency=concurrency_per_client, runtime=EXPERIMENT_RUNTIME_STRING,
                                   stats_freq=STATS_FREQUENCY, workload_filename=MEMASLAP_WORKLOAD,
                                   log_filename=log_filename_base.format(2, ms_concurrencies[i], rep))
        time.sleep(EXPERIMENT_RUNTIME + 5)
        memcached_server.stop()
# endregion

# region ---- Gather logs ----
memaslap_server1.download_logs(local_path=results_dir)
memaslap_server2.download_logs(local_path=results_dir)
# endregion

deployer.hibernate_wait()