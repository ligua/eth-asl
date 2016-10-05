from azure.common.credentials import UserPassCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.storage import StorageManagementClient
from azure.storage import CloudStorageAccount
from azure.storage.blob.models import ContentSettings
from deployer import Deployer

credentials = UserPassCredentials('sinep@sq42nahotmail.onmicrosoft.com', "4D0$1QcK5:Nsn:jd!'1j4Uw'j*")
subscription_id = '0003c64e-455e-4794-8665-a59c04a8961b'

resource_client = ResourceManagementClient(credentials, subscription_id)
storage_client = StorageManagementClient(credentials, subscription_id)


resource_group_name = "for_asl_py_test"

deployer = Deployer(resource_group_name)
deployer.deploy()
deployer.destroy()