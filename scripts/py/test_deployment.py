import os.path
from haikunator import Haikunator
from deployer import Deployer

# region ---- Credentials ----
my_subscription_id = "0003c64e-455e-4794-8665-a59c04a8961b"
my_email = "sinep@sq42nahotmail.onmicrosoft.com"
my_password = "4D0$1QcK5:Nsn:jd!'1j4Uw'j*"
# endregion

# region ---- Parameters ----
my_resource_group = 'azure-python-deployment-sample-2'
my_pub_ssh_key_path = os.path.expanduser('~/.ssh/id_rsa.pub')
template_path = "azure-templates/test_template.json"
dns_label_prefix = Haikunator().haikunate()

pub_ssh_key_path = os.path.expanduser(my_pub_ssh_key_path)
with open(pub_ssh_key_path, 'r') as pub_ssh_file_fd:
    pub_ssh_key = pub_ssh_file_fd.read()

parameters = {
    'sshKeyData': pub_ssh_key,
    'vmName': 'azure-deployment-sample-vm',
    'dnsLabelPrefix': dns_label_prefix
}
# endregion

# region ---- Deployment ----
# Initialize the deployer class
deployer = Deployer(my_email, my_password, my_subscription_id, my_resource_group, template_path, parameters)

# Deploy the template
my_deployment = deployer.deploy()

print("Done deploying!\n\nConnect via: `ssh azureSample@{}.westeurope.cloudapp.azure.com`".format(dns_label_prefix))
# endregion

# Destroy the resource group which contains the deployment
deployer.destroy()
