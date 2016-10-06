import os.path
from deployer import Deployer

# region ---- Credentials ----
my_subscription_id = "0003c64e-455e-4794-8665-a59c04a8961b"
my_email = "sinep@sq42nahotmail.onmicrosoft.com"
my_password = "4D0$1QcK5:Nsn:jd!'1j4Uw'j*"
my_pub_ssh_key_path = os.path.expanduser('~/.ssh/id_rsa.pub')  # the path to your rsa public key file
# endregion

# region ---- Parameters ----
my_resource_group = 'azure-python-deployment-sample'  # the resource group for deployment
template_path = "azure-templates/test_template.json"
# endregion

# region ---- Deployment ----
msg = "\nInitializing the Deployer class with subscription id: {}, resource group: {}" \
      "\nand public key located at: {}...\n\n"
msg = msg.format(my_subscription_id, my_resource_group, my_pub_ssh_key_path)
print(msg)

# Initialize the deployer class
deployer = Deployer(my_email, my_password, my_subscription_id, my_resource_group, template_path, my_pub_ssh_key_path)

print("Beginning the deployment... \n\n")
# Deploy the template
my_deployment = deployer.deploy()

print("Done deploying!!\n\nYou can connect via: `ssh azureSample@{}.westus.cloudapp.azure.com`".format(
    deployer.dns_label_prefix))
# endregion

# Destroy the resource group which contains the deployment
deployer.destroy()
