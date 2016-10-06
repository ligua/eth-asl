"""A deployer class to deploy a template on Azure"""
import json
import logging
import sys
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode
from azure.common.credentials import UserPassCredentials


class Deployer(object):

    def __init__(self, user_email, user_password, subscription_id, resource_group, template_path, parameters):
        self.resource_group = resource_group
        self.deployment_name = "taivo_foo_deployment"
        self.template_path = template_path
        self.parameters = parameters

        self.credentials = UserPassCredentials(user_email, user_password)
        self.client = ResourceManagementClient(self.credentials, subscription_id)

        # region ---- Set up logging ----
        LOG_FORMAT = '%(asctime)-15s %(message)s'
        LOG_LEVEL = logging.INFO
        formatter = logging.Formatter(LOG_FORMAT)

        ch = logging.StreamHandler()
        ch.setLevel(LOG_LEVEL)
        ch.setFormatter(formatter)

        self.log = logging.getLogger(__name__)
        self.log.setLevel(LOG_LEVEL)
        self.log.addHandler(ch)
        # endregion

    def deploy(self):
        """Deploy the template to a resource group."""

        self.log.info("Initializing Deployer class with resource group '{}' and template at '{}'."
                     .format(self.resource_group, self.template_path))
        self.log.info("Parameters: " + str(self.parameters))
        self.client.resource_groups.create_or_update(
            self.resource_group, {'location': 'westeurope'}
        )

        with open(self.template_path, 'r') as template_file_fd:
            template = json.load(template_file_fd)

        parameters = {k: {'value': v} for k, v in self.parameters.items()}

        deployment_properties = {
            'mode': DeploymentMode.complete,    # Deployment modes: https://azure.microsoft.com/en-us/documentation/articles/resource-group-template-deploy/#incremental-and-complete-deployments
            'template': template,
            'parameters': parameters
        }

        deployment_async_operation = self.client.deployments.create_or_update(
            self.resource_group,
            self.deployment_name,
            deployment_properties
        )
        deployment_async_operation.wait()

        self.log.info("Deployment complete, resource group {} created.".format(self.resource_group))

    def destroy(self):
        """Destroy the given resource group"""
        self.log.info("Destroying resource group {}...".format(self.resource_group))
        self.log.info("Does it exist? {}".format(
            self.client.resource_groups.check_existence(self.resource_group))
        )
        deletion_async_operation = self.client.resource_groups.delete(self.resource_group)
        deletion_async_operation.wait()
        self.log.info("Destroyed.")
