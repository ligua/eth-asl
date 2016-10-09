"""A deployer class to deploy a template on Azure"""
import json
import logging
import time
from colors import Colors
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.storage import StorageManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode
from azure.common.credentials import UserPassCredentials
from azure.mgmt.resource.resources.operations import ResourceGroupsOperations


class Deployer(object):

    TYPE_VIRTUAL_MACHINE = "Microsoft.Compute/virtualMachines"
    TYPE_NETWORK_INTERFACE = "Microsoft.Network/networkInterfaces"
    TYPE_PUBLIC_IP = "Microsoft.Network/publicIPAddresses"
    TYPE_VIRTUAL_NETWORK = "Microsoft.Network/virtualNetworks"
    TYPE_STORAGE_ACCOUNT = "Microsoft.Storage/storageAccounts"

    def __init__(self, resource_group_name, template_path, parameters,
                 user_email="sinep@sq42nahotmail.onmicrosoft.com",
                 user_password="4D0$1QcK5:Nsn:jd!'1j4Uw'j*",
                 subscription_id="0003c64e-455e-4794-8665-a59c04a8961b"):
        # region ---- Set instance fields ----
        self.resource_group_name = resource_group_name
        self.deployment_name = "taivo_python_deployment"
        self.template_path = template_path
        self.parameters = parameters

        self.credentials = UserPassCredentials(user_email, user_password)
        self.resource_client = ResourceManagementClient(self.credentials, subscription_id)
        self.compute_client = ComputeManagementClient(self.credentials, subscription_id)
        self.network_client = NetworkManagementClient(self.credentials, subscription_id)
        self.storage_client = StorageManagementClient(self.credentials, subscription_id)

        # endregion

        # region ---- Set up logging ----
        LOG_FORMAT = '%(asctime)-15s [%(name)s] - %(message)s'
        LOG_LEVEL = logging.INFO
        formatter = logging.Formatter(LOG_FORMAT)

        ch = logging.StreamHandler()
        ch.setLevel(LOG_LEVEL)
        ch.setFormatter(formatter)

        self.log = logging.getLogger(__name__)
        self.log.setLevel(LOG_LEVEL)
        self.log.addHandler(ch)
        # endregion

        # region ---- Find if resource group exists ----
        already_exists = self.resource_client.resource_groups.check_existence(self.resource_group_name)
        if already_exists:
            self.log.info("Resource group already exists:")
            resources = self.resource_client.resource_groups.list_resources(self.resource_group_name)
            for res in resources:
                self.log.info(Deployer.stringify_resource(res))
        else:
            self.log.info("Resource group does not exist yet.")
        # endregion
        pass

    def _deploy(self):
        """Deploy the template to a resource group."""

        self.log.info("Deploying with resource group '{}' and template at '{}'."
                      .format(self.resource_group_name, self.template_path))
        self.log.info("Parameters: " + str(self.parameters))
        self.resource_client.resource_groups.create_or_update(
            self.resource_group_name, {'location': 'westeurope'}
        )

        with open(self.template_path, 'r') as template_file_fd:
            template = json.load(template_file_fd)

        parameters = {k: {'value': v} for k, v in self.parameters.items()}

        deployment_properties = {
            'mode': DeploymentMode.complete,
            'template': template,
            'parameters': parameters
        }

        deployment_async_operation = self.resource_client.deployments.create_or_update(
            self.resource_group_name,
            self.deployment_name,
            deployment_properties
        )

        self.log.info("Started deployment of resource group {}.".format(self.resource_group_name))

        return deployment_async_operation

    def deploy_wait(self):
        """Convenience method that blocks until deployment is done."""
        # region ---- Creating all resources -----
        deployment_async_operation = self._deploy()
        deployment_async_operation.wait()
        # endregion

        # region ---- Un-hibernating all VMs ----
        async_ops = []
        resources = self.resource_client.resource_groups.list_resources(self.resource_group_name)
        for resource in resources:
            if resource.type == Deployer.TYPE_VIRTUAL_MACHINE:
                self.log.info("Starting virtual machine {}...".format(resource.name))
                async_op = self.compute_client.virtual_machines.start(self.resource_group_name, resource.name)
                async_ops.append(async_op)

        self.wait_for_all_ops(async_ops)
        # endregion

        self.log.info("Deployment complete, resource group {} created.".format(self.resource_group_name))

    def hibernate_wait(self):
        """Shut down all virtual machines in the resource group and delete all other resources."""
        self.log.info("Hibernating resource group {}.".format(self.resource_group_name))
        resources = self.resource_client.resource_groups.list_resources(self.resource_group_name)

        async_ops = []

        for resource in resources:
            if resource.type == Deployer.TYPE_VIRTUAL_MACHINE:
                self.log.info("Deallocating virtual machine {}...".format(resource.name))
                async_op = self.compute_client.virtual_machines.deallocate(self.resource_group_name, resource.name)
                async_ops.append(async_op)
            elif resource.type == Deployer.TYPE_NETWORK_INTERFACE:
                self.log.info("Not deleting network interface {}.".format(resource.name))
                # self.log.info("Deleting network interface {}...".format(resource.name))
                # async_op = self.network_client.network_interfaces.delete(self.resource_group_name, resource.name)
                # async_ops.append(async_op)
            elif resource.type == Deployer.TYPE_PUBLIC_IP:
                self.log.info("Not deleting public IP {}.".format(resource.name))
                # self.log.info("Deleting public IP {}...".format(resource.name))
                # async_op = self.network_client.public_ip_addresses.delete(self.resource_group_name, resource.name)
                # async_ops.append(async_op)
            elif resource.type == Deployer.TYPE_VIRTUAL_NETWORK:
                self.log.info("Not deleting virtual network {}.".format(resource.name))
                # self.log.info("Deleting virtual network {}...".format(resource.name))
                # async_op = self.network_client.virtual_networks.delete(self.resource_group_name, resource.name)
                # async_ops.append(async_op)
            elif resource.type == Deployer.TYPE_STORAGE_ACCOUNT:
                self.log.info("Not deleting storage account {}.".format(resource.name))
                # self.log.info("Deleting storage account {}...".format(resource.name))
                # async_op = self.storage_client.storage_accounts.delete(self.resource_group_name, resource.name)
                # async_ops.append(async_op)
            else:
                self.log.info("Not deleting unknown resource {} [{}].".format(resource.name, resource.type))

        self.wait_for_all_ops(async_ops)

    def _destroy(self):
        """Destroy the given resource group"""
        self.log.info("Destroying resource group {}...".format(self.resource_group_name))
        deletion_async_operation = self.resource_client.resource_groups.delete(self.resource_group_name)
        self.log.info("Started deletion of resource group {}.".format(self.resource_group_name))

        return deletion_async_operation

    def destroy_wait(self):
        """Convenience method that blocks until deletion is done."""
        deletion_async_operation = self._destroy()
        deletion_async_operation.wait()
        self.log.info("Resource group {} destroyed.".format(self.resource_group_name))

    def wait_for_all_ops(self, async_ops, log_every_n_seconds=5):
        """Wait for all operations in the list to finish"""
        self.log.info("Waiting for {} operations to finish...".format(len(async_ops)))

        start_time = time.time()
        while async_ops:
            if time.time() - start_time > log_every_n_seconds:
                start_time = time.time()
                self.log.info("{} operations still not done.".format(len(async_ops)))
            for op in async_ops:
                if op.done():
                    "Async operation done. Result: {}".format(op.result())
                    async_ops.remove(op)
                    break

        self.log.info("All operations done.")

    @staticmethod
    def kill(resource_group):
        """Kill the given resource group."""
        print("Killing resource group {}...".format(resource_group))
        d = Deployer(None, None, None)
        deletion_async_operation = d.resource_client.resource_groups.delete(resource_group)
        print("Started killing resource group {}.".format(resource_group))

        return deletion_async_operation

    @staticmethod
    def kill_wait(resource_group):
        deletion_async_operation = Deployer.kill(resource_group)
        deletion_async_operation.wait()
        print("Resource group {} destroyed.".format(resource_group))

    @staticmethod
    def stringify_properties(props):
        """Print a ResourceGroup properties instance."""
        s = ""
        if props and props.provisioning_state:
            s += "\tProperties:\n"
            s += "\t\tProvisioning State: {}\n".format(props.provisioning_state)
        s += "\n"
        return s

    @staticmethod
    def stringify_resource(res):
        """Print a ResourceGroup instance."""
        s = ""
        s += "\tName: {}\n".format(Colors.ok_blue(Colors.bold(res.name)))
        s += "\tType: {}\n".format(res.type)
        s += "\tId: {}\n".format(res.id)
        s += "\tLocation: {}\n".format(res.location)
        s += "\tTags: {}\n".format(res.tags)
        s += Deployer.stringify_properties(res.properties)
        return s
