import os.path
from haikunator import Haikunator
from deployer import Deployer

# region ---- Credentials ----
my_subscription_id = "0003c64e-455e-4794-8665-a59c04a8961b"
my_email = "sinep@sq42nahotmail.onmicrosoft.com"
my_password = "4D0$1QcK5:Nsn:jd!'1j4Uw'j*"
# endregion

# region ---- Parameters ----
my_resource_group = 'azure-python-deployment-test-small-1'
my_pub_ssh_key_path = os.path.expanduser('~/.ssh/id_rsa.pub')
template_path = "azure-templates/template3vms.json"
dns_label_prefix = "pungast"

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
deployer = Deployer(my_email, my_password, my_subscription_id, my_resource_group, template_path, parameters)

# Deploy the template
my_deployment = deployer.deploy_wait()
# endregion

input("Write anything to destroy the resource group: ")

# Destroy the resource group which contains the deployment
deployer.destroy_wait()
