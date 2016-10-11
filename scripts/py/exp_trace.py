import os.path
import logging
import threading
import time
from memaslap import Memaslap
from memcached import Memcached
from middleware import Middleware

from colors import Colors
from deployer import Deployer

UPDATE_AND_INSTALL = True
EXPERIMENT_RUNTIME = 1  # minutes
EXPERIMENT_RUNTIME_STRING = "{}m".format(EXPERIMENT_RUNTIME)
STATS_FREQUENCY = "10m"
NUM_THREADS_IN_POOL = 1
REPLICATION_FACTOR = 1

# region ---- Logging ----
LOG_FORMAT = '%(asctime)-15s [%(name)s_(%(threadName)-4s)] - %(message)s'
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
def wait_for_all_threads():
    log.info("Waiting for all threads to finish...")
    for t in threading.enumerate():
        if t is threading.current_thread():
            continue
        log.info('Joining thread %s', t.getName())
        t.join()


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
    mc_server = Memcached(memcached_port, public_hostnames[i])
    mc_servers.append(mc_server)
    mc_server_string_list.append("{}:{}".format(private_hostnames, memcached_port))
    if UPDATE_AND_INSTALL:
        t = threading.Thread(name="mc{}".format(i), target=mc_server.update_and_install())

wait_for_all_threads()
#for s in mc_servers:
#    s.start()

# Set up middleware server
middleware_port = 11212
log.info("Setting up middleware on machine {} ({}).".format(index_a4, vm_names[index_a4]))
mw_server = Middleware(public_hostnames[index_a4], private_hostnames[index_a4], middleware_port,
                       NUM_THREADS_IN_POOL, REPLICATION_FACTOR, mc_server_string_list)
if UPDATE_AND_INSTALL:
    threading.Thread(name="mw", target=mw_server.update_and_install())

#mw_server.start()

# Set up memaslap servers
ms_servers = []
for i in indices_smallmachines[3:]:
    log.info("Setting up memaslap on machine {} ({}).".format(i, vm_names[i]))
    ms_server = Memaslap(public_hostnames[i], private_hostnames[index_a4], middleware_port)
    ms_servers.append(ms_server)
    if UPDATE_AND_INSTALL:
        t = threading.Thread(name="ms{}".format(i), target=ms_server.update_and_install())

wait_for_all_threads()
#for s in ms_servers:
#    s.start()

# endregion


# region ---- Kill everyone ---- (TODO sleep before though?)
# Memaslap
#for ms_server in ms_servers:
#    ms_server.stop()

# Middleware
#mw_server.stop()

# Memcached
#for mc_server in mc_servers:
#    mc_server.stop()

# endregion













