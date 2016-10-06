import os.path
from haikunator import Haikunator
from deployer import Deployer

# region ---- Parameters ----
my_resource_group = 'azure-python-deployment-test-4'
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
deployer = Deployer(my_resource_group, template_path, parameters)

# Deploy the template
my_deployment = deployer.deploy_wait()
# endregion

# Destroy the resource group which contains the deployment
deployer.destroy_wait()
