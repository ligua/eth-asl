import os.path
import logging
import threading
import time
from memaslap import Memaslap
from memcached import Memcached
from middleware import Middleware

from colors import Colors
from deployer import Deployer

UPDATE_AND_INSTALL = False
UPDATE_AND_INSTALL_ONLY_MIDDLEWARE = True
EXPERIMENT_RUNTIME = 1  # minutes
RUNTIME_BUFFER = 60     # seconds
EXPERIMENT_RUNTIME_STRING = "{}m".format(EXPERIMENT_RUNTIME)
STATS_FREQUENCY = "30s"
NUM_THREADS_IN_POOL = 5
REPLICATION_FACTOR = 3

ssh_username = "pungast7"
results_dir = "results/trace"

# region ---- Logging ----
LOG_FORMAT = '%(asctime)-15s [%(name)s] - %(message)s'
LOG_LEVEL = logging.INFO
formatter = logging.Formatter(LOG_FORMAT)

ch = logging.StreamHandler()
ch.setLevel(LOG_LEVEL)
ch.setFormatter(formatter)

ch2 = logging.FileHandler("{}/deployment.log".format(results_dir))
ch2.setLevel(LOG_LEVEL)
ch2.setFormatter(formatter)

log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)
log.addHandler(ch)
log.addHandler(ch2)
# endregion

# region ---- Parameters ----
resource_group_name = 'template7vms'
my_pub_ssh_key_path = '~/.ssh/id_rsa_asl.pub'
template_path = "azure-templates/template7vms.json"
dns_label_prefix = "pungast7"
virtual_network_name = "MyVNet7m"

pub_ssh_key_path = os.path.expanduser(my_pub_ssh_key_path)
with open(pub_ssh_key_path, 'r') as pub_ssh_file_fd:
    pub_ssh_key = pub_ssh_file_fd.read().strip()

parameters = {
    "virtualMachines_name": "foraslvms7m",
    "virtualMachines_adminPassword": "U6Mh=be:vma+&>R'pcMwFVls?=",
    "networkInterfaces_name": "MyNetworkInterface7m",
    "virtualNetworks_testeth_vnet_name": virtual_network_name,
    "key": pub_ssh_key,
    "uniquedns": dns_label_prefix
}
# endregion

# Initialize the deployer class
deployer = Deployer(resource_group_name, template_path, parameters)
deployer.deploy_wait()

# region ---- Extract VMs' IPs and other information ----
vms = deployer.compute_client.virtual_machines.list(resource_group_name)
vm_names = []
vm_types = []
public_hostnames = []
private_hostnames = []

for vm in vms:
    vm_type = vm.hardware_profile.vm_size
    vm_types.append(vm_type)
    vm_names.append(vm.name)
    log.info("VM {} [{}]".format(Colors.ok_blue(vm.name), vm_type))

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


# region ---- Set up all machines ----
index_a4 = vm_types.index("Basic_A4")
indices_smallmachines = list(range(7))
indices_smallmachines.remove(index_a4)

log.info("A2 machines: " + str(indices_smallmachines))
log.info("A4 machine: " + str(index_a4))

# Set up memcached servers
memcached_port = 11211
mc_servers = []
mc_server_string_list = []
for i in indices_smallmachines[0:3]:
    log.info("Setting up memcached on machine {} ({}).".format(i, vm_names[i]))
    mc_server = Memcached(memcached_port, public_hostnames[i], ssh_username=ssh_username)
    mc_servers.append(mc_server)
    mc_server_string_list.append("{}:{}".format(private_hostnames[i], memcached_port))
    if UPDATE_AND_INSTALL:
        mc_server.update_and_install()
for s in mc_servers:
    s.start()

# Set up middleware server
middleware_port = 11212
log.info("Setting up middleware on machine {} ({}).".format(index_a4, vm_names[index_a4]))
mw_server = Middleware(public_hostnames[index_a4], private_hostnames[index_a4], middleware_port,
                       NUM_THREADS_IN_POOL, REPLICATION_FACTOR, mc_server_string_list, ssh_username=ssh_username)
if UPDATE_AND_INSTALL or UPDATE_AND_INSTALL_ONLY_MIDDLEWARE:
    mw_server.update_and_install()

mw_server.clear_logs()
mw_server.start()

# Sleep a bit so middleware has time to start
if not mw_server.is_running():
    sleep_for = 5
    log.info("Sleeping for {} seconds so middleware can start...".format(sleep_for))
    time.sleep(sleep_for)

# Set up memaslap servers
ms_servers = []
first_memaslap = True
for i in indices_smallmachines[3:]:
    log.info("Setting up memaslap on machine {} ({}).".format(i, vm_names[i]))
    ms_server = Memaslap(public_hostnames[i], private_hostnames[index_a4], middleware_port, ssh_username=ssh_username,
                         id_number=i+1) # i is zero-indexed
    ms_servers.append(ms_server)
    if UPDATE_AND_INSTALL:
        if not first_memaslap:
            ms_server.upload_built_files()

        ms_server.update_and_install()

        if first_memaslap:
            ms_server.download_built_files()
            first_memaslap = False

for s in ms_servers:
    s.clear_logs()
    s.start(runtime=EXPERIMENT_RUNTIME_STRING, log_filename="memaslap{}.out".format(s.id_number),
            stats_freq=STATS_FREQUENCY)

# endregion

log.info("Waiting for the experiment to finish, sleeping for {} minutes.".format(EXPERIMENT_RUNTIME))
already_slept = 0
while True:
    time.sleep(60)
    already_slept += 60
    log.info("Waiting for the experiment to finish, {:.0f}/{} minutes elapsed ({:.0f}%)."
             .format(already_slept/60, EXPERIMENT_RUNTIME, 100*already_slept/60.0/EXPERIMENT_RUNTIME))
    if already_slept >= EXPERIMENT_RUNTIME * 60:
        break

log.info("Giving some extra time to memaslap, sleeping for {} seconds.".format(RUNTIME_BUFFER))
time.sleep(RUNTIME_BUFFER)

# region ---- Kill everyone ----
# Memaslap
for ms_server in ms_servers:
    ms_server.stop()

# Middleware
mw_server.stop()

# Memcached
for mc_server in mc_servers:
    mc_server.stop()

# endregion

# region ---- Download logs ----
mw_server.download_logs(local_path=results_dir)
for ms_server in ms_servers:
    ms_server.download_logs(local_path=results_dir)

# endregion

# deployer.hibernate_wait()

log.info("Done.")









