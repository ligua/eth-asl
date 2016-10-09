import os.path
import logging
import time
from memaslap import Memaslap
from memcached import Memcached

from colors import Colors
from deployer import Deployer

UPDATE_AND_INSTALL = False
EXPERIMENT_RUNTIME = 10  # seconds
EXPERIMENT_RUNTIME_STRING = "{}s".format(EXPERIMENT_RUNTIME)

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

ms_concurrencies = [1, 2, 4] # + list(range(8, 129, 8))

for i in range(0, len(ms_concurrencies)):
    log.info("Starting experiment at concurrency {}.".format(ms_concurrencies[i]))
    memcached_server.start()
    time.sleep(1)
    memaslap_server1.start(concurrency=ms_concurrencies[i], runtime=EXPERIMENT_RUNTIME_STRING,
                           log_filename="baseline_client{}_conc{:03}.out".format(1, ms_concurrencies[i]))
    if ms_concurrencies[i] > 1:
        memaslap_server2.start(concurrency=ms_concurrencies[i], runtime=EXPERIMENT_RUNTIME_STRING,
                               log_filename="baseline_client{}_conc{:03}.out".format(2, ms_concurrencies[i]))
    time.sleep(EXPERIMENT_RUNTIME + 5)






memcached_server.start()
memaslap_server1.start()
memaslap_server2.start()
# endregion

# Wait until experiment is done
time.sleep(12)  # TODO change this -- perhaps ask memaslap servers whether the process still exists


# region ---- Stop memcached ----
memcached_server.stop()
# endregion

#input("Write anything to start hibernation: ")

#deployer.hibernate_wait()