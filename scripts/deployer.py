"""A deployer class to deploy a template on Azure"""
import os.path
import json
from azure.common.credentials import UserPassCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode

class Deployer(object):

    def __init__(self, resource_group):
        self.resource_group = resource_group
        self.dns_label_prefix = "taivoasd"

        credentials = UserPassCredentials('sinep@sq42nahotmail.onmicrosoft.com', "4D0$1QcK5:Nsn:jd!'1j4Uw'j*")
        subscription_id = '0003c64e-455e-4794-8665-a59c04a8961b'
        self.client = ResourceManagementClient(credentials, subscription_id)

    def deploy(self):
        """Deploy the template to a resource group."""
        self.client.resource_groups.create_or_update(
            self.resource_group,
            {
                'location':'westeurope'
            }
        )

        template_path = "azure-templates/template3vms.json"

        with open(template_path, 'r') as template_file_fd:
            template = json.load(template_file_fd)

        deployment_properties = {
            'mode': DeploymentMode.incremental,
            'template': template,
            'parameters': parameters
        }

        deployment_async_operation = self.client.deployments.create_or_update(
            self.resource_group,
            'azure-sample',
            deployment_properties
        )
        deployment_async_operation.wait()

    def destroy(self):
        """Destroy the given resource group"""
        self.client.resource_groups.delete(self.resource_group)