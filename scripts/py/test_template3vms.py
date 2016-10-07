import os.path
from haikunator import Haikunator
from deployer import Deployer

# region ---- Parameters ----
my_resource_group = 'template3vms'
my_pub_ssh_key_path = '~/.ssh/id_rsa_asl.pub'
template_path = "azure-templates/template3vms.json"
dns_label_prefix = "pungast"

pub_ssh_key_path = os.path.expanduser(my_pub_ssh_key_path)
with open(pub_ssh_key_path, 'r') as pub_ssh_file_fd:
    pub_ssh_key = pub_ssh_file_fd.read().strip()

parameters = {
    "virtualMachines_name": "foraslvms",
    "virtualMachines_adminPassword": "U6Mh=be:vma+&>R'pcMwFVls?=",
    "networkInterfaces_name": "MyNetworkInterface",
    "virtualNetworks_testeth_vnet_name": "MyVNet",
    "key": pub_ssh_key,
    "uniquedns": dns_label_prefix
}
# endregion

# region ---- Deployment ----
# Initialize the deployer class
deployer = Deployer(my_resource_group, template_path, parameters)

deployer.hibernate()

# Deploy the template
# deployer.deploy_wait()
# endregion

#input("Write anything to destroy the resource group: ")

# Destroy the resource group which contains the deployment
#deployer.destroy_wait()
