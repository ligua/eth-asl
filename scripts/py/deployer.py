"""A deployer class to deploy a template on Azure"""
import json
import logging
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode
from azure.common.credentials import UserPassCredentials


class Deployer(object):

    def __init__(self, user_email, user_password, subscription_id, resource_group, template_path, parameters):
        self.resource_group = resource_group
        self.template_path = template_path
        self.parameters = parameters

        self.credentials = UserPassCredentials(user_email, user_password)
        self.client = ResourceManagementClient(self.credentials, subscription_id)

        LOG_FORMAT = '%(asctime)-15s %(message)s'
        logging.basicConfig(format=LOG_FORMAT, level=logging.INFO)

    def deploy(self):
        """Deploy the template to a resource group."""

        logging.info("Initializing Deployer class with resource group '{}' and template at '{}'."
                      .format(self.resource_group, self.template_path))
        logging.info("Parameters: " + str(self.parameters))

        self.client.resource_groups.create_or_update(
            self.resource_group, {'location': 'westeurope'}
        )

        with open(self.template_path, 'r') as template_file_fd:
            template = json.load(template_file_fd)

        parameters = {k: {'value': v} for k, v in self.parameters.items()}

        # TODO review deployment mode -- what do I want?
        deployment_properties = {
            'mode': DeploymentMode.incremental,
            'template': template,
            'parameters': parameters
        }

        deployment_async_operation = self.client.deployments.create_or_update(
            self.resource_group,
            'azure-sample',         # TODO what is this parameter?
            deployment_properties
        )
        deployment_async_operation.wait()

        logging.info("Deployment complete, resource group {} created.".format(self.resource_group))

    def destroy(self):
        """Destroy the given resource group"""
        logging.info("Destroying resource group {}...".format(self.resource_group))
        self.client.resource_groups.delete(self.resource_group)
        logging.info("Destroyed.")
