import os.path
import logging

from colors import Colors
from deployer import Deployer

# region ---- Logging ----
LOG_FORMAT = '%(asctime)-15s %(message)s'
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


vms = deployer.compute_client.virtual_machines.list(resource_group_name)
for vm in vms:
    log.info("VM {}".format(Colors.ok_blue(vm.name)))
    # Get machine's public address that we can use for SSH-ing
    public_ip = deployer.network_client.public_ip_addresses.get(resource_group_name, vm.name)
    public_host_address = public_ip.dns_settings.fqdn
    log.info("Public host name: {}".format(Colors.ok_green(public_host_address)))

    # Get machine's private IP address
    network_interface_id = vm.network_profile.network_interfaces[0].id
    network_interface_name = network_interface_id.split("/")[-1]
    network_interface = deployer.network_client.network_interfaces.get(resource_group_name, network_interface_name)
    private_host_address = network_interface.ip_configurations[0].private_ip_address
    log.info("Private host name: {}".format(Colors.ok_green(private_host_address)))

#input("Write anything to start hibernation: ")

#deployer.hibernate_wait()