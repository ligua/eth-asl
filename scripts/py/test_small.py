import os.path
from haikunator import Haikunator
from deployer import Deployer

# region ---- Parameters ----
my_resource_group = 'azure-python-deployment-test-small-4'
my_pub_ssh_key_path = os.path.expanduser('~/.ssh/id_rsa.pub')
template_path = "azure-templates/template3vms.json"
dns_label_prefix = "pungast" + Haikunator().haikunate()

pub_ssh_key_path = os.path.expanduser(my_pub_ssh_key_path)
with open(pub_ssh_key_path, 'r') as pub_ssh_file_fd:
    pub_ssh_key = pub_ssh_file_fd.read()

parameters = {
    # "virtualMachines_name": "foraslvms",
    "virtualMachines_adminPassword": "U6Mh=be:vma+&>R'pcMwFVls?=",
    # "networkInterfaces_name": "MyNetworkInterface",
    # "virtualNetworks_testeth_vnet_name": "MyVNet",
    "key": pub_ssh_key,
    "uniquedns": dns_label_prefix
}
# endregion

# region ---- Deployment ----
# Initialize the deployer class
deployer = Deployer(my_resource_group, template_path, parameters)

# Deploy the template
my_deployment = deployer.deploy_wait()
# endregion

input("Write anything to destroy the resource group: ")

# Destroy the resource group which contains the deployment
deployer.destroy_wait()
