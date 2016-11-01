import os.path
import logging
import time
import aslutil

import fabric.api
from memaslap import Memaslap
from memcached import Memcached
from middleware import Middleware

from colors import Colors
from deployer import Deployer

class Experiment():
    def __init__(self):
        # region ---- Logging ----
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

    def start_experiment(self,
            results_dir,
            update_and_install=False,
            experiment_runtime = 5,     # minutes
            runtime_buffer = 1,         # minutes
            stats_frequency ="30s",
            num_threads_in_pool = 5,
            replication_factor = 1,
            memaslap_workload = "smallvalue.cfg",
            hibernate_at_end = True,
            ssh_username = "pungast",
            num_memaslaps = 1,
            num_memcacheds = 1
    ):
        experiment_runtime_string = "{}m".format(experiment_runtime)
    
        with fabric.api.settings(warn_only=True):
            fabric.api.local("rm -r {}/*".format(results_dir))
            fabric.api.local("mkdir -p {}".format(results_dir))
    
        # region ---- Parameters ----
        TOTAL_MACHINE_COUNT = 11  # this is fixed by the template
        resource_group_name = 'template11vms'
        my_pub_ssh_key_path = '~/.ssh/id_rsa_asl.pub'
        template_path = "azure-templates/template11vms.json"

        pub_ssh_key_path = os.path.expanduser(my_pub_ssh_key_path)
        with open(pub_ssh_key_path, 'r') as pub_ssh_file_fd:
            pub_ssh_key = pub_ssh_file_fd.read().strip()
    
        parameters = {
            "virtualMachines_name": "foraslvms",
            "virtualMachines_adminPassword": "U6Mh=be:vma+&>R'pcMwFVls?=",
            "networkInterfaces_name": "MyNetworkInterface",
            "virtualNetworks_testeth_vnet_name": "MyVNet",
            "key": pub_ssh_key,
            "uniquedns": "pungast"
        }
        # endregion
    
        # Initialize the deployer class
        deployer = Deployer(resource_group_name, template_path, parameters)
        deployer.deploy_wait()
    
        # region ---- Extract VMs' IPs and other information ----
        vms = deployer.compute_client.virtual_machines.list(resource_group_name)
        vm_names = []
        vm_types = []
        public_hostnames = []
        private_hostnames = []
    
        for vm in vms:
            vm_type = vm.hardware_profile.vm_size
            vm_types.append(vm_type)
            vm_names.append(vm.name)
            self.log.info("VM {} [{}]".format(Colors.ok_blue(vm.name), vm_type))
    
            # Get machine's public address that we can use for SSH-ing
            public_ip = deployer.network_client.public_ip_addresses.get(resource_group_name, vm.name)
            public_host_address = public_ip.dns_settings.fqdn
            public_hostnames.append(public_host_address)
            self.log.info("Public host name: {}".format(Colors.ok_green(public_host_address)))
    
            # Get machine's private IP address
            network_interface_id = vm.network_profile.network_interfaces[0].id
            network_interface_name = network_interface_id.split("/")[-1]
            network_interface = deployer.network_client.network_interfaces.get(resource_group_name, network_interface_name)
            private_host_address = network_interface.ip_configurations[0].private_ip_address
            private_hostnames.append(private_host_address)
            self.log.info("Private host name: {}".format(Colors.ok_green(private_host_address)))
    
        # endregion

        # region ---- Set up all machines ----
        index_a4 = vm_types.index("Basic_A4")
        indices_smallmachines = list(range(TOTAL_MACHINE_COUNT))
        indices_smallmachines.remove(index_a4)
    
        self.log.info("A2 machines: " + str(indices_smallmachines))
        self.log.info("A4 machine: " + str(index_a4))

        # Wait for all servers to be responsive
        aslutil.wait_for_servers(ssh_username, public_hostnames, "~/.ssh/id_rsa_asl", self.log, check_every_n_sec=10)

        # Set up memcached servers
        memcached_port = 11211
        mc_servers = []
        mc_server_string_list = []
        for i in indices_smallmachines[0:num_memcacheds]:
            self.log.info("Setting up memcached on machine {} ({}).".format(i, vm_names[i]))
            mc_server = Memcached(memcached_port, public_hostnames[i], ssh_username=ssh_username)
            mc_servers.append(mc_server)
            mc_server_string_list.append("{}:{}".format(private_hostnames[i], memcached_port))
            if update_and_install:
                mc_server.update_and_install()
        for s in mc_servers:
            s.start()
    
        # Set up middleware server
        middleware_port = 11212
        self.log.info("Setting up middleware on machine {} ({}).".format(index_a4, vm_names[index_a4]))
        mw_server = Middleware(public_hostnames[index_a4], private_hostnames[index_a4], middleware_port,
                               num_threads_in_pool, replication_factor, mc_server_string_list, ssh_username=ssh_username)
        if update_and_install:
            mw_server.update_and_install()
        mw_server.upload_jar()

        mw_server.stop()
        mw_server.clear_logs()
        mw_server.start()
    
        # Sleep a bit so middleware has time to start
        sleep_for = 5
        while not mw_server.is_running():
            self.log.info("Sleeping for {} seconds so middleware can start...".format(sleep_for))
            time.sleep(sleep_for)
    
        # Set up memaslap servers
        ms_servers = []
        first_memaslap = True
        for i in indices_smallmachines[num_memcacheds:num_memcacheds+num_memaslaps]:
            self.log.info("Setting up memaslap on machine {} ({}).".format(i, vm_names[i]))
            ms_server = Memaslap(public_hostnames[i], private_hostnames[index_a4], middleware_port, ssh_username=ssh_username,
                                 id_number=int(aslutil.server_name_to_number(vm_names[i]))) # i is zero-indexed
            ms_servers.append(ms_server)
            if update_and_install:
                if not first_memaslap:
                    ms_server.upload_built_files()
    
                ms_server.update_and_install()
    
                if first_memaslap:
                    ms_server.download_built_files()
                    first_memaslap = False
    
        for s in ms_servers:
            s.clear_logs()
            s.start(runtime=experiment_runtime_string, log_filename="memaslap{}.out".format(s.id_number),
                    stats_freq=stats_frequency,
                    workload_filename=memaslap_workload)
    
        # endregion
    
        self.log.info("Waiting for the experiment to finish, sleeping for {} minutes.".format(experiment_runtime))
        already_slept = 0
        while True:
            time.sleep(60)
            already_slept += 60
            self.log.info("Waiting for the experiment to finish, {:.0f}/{} minutes elapsed ({:.0f}%)."
                     .format(already_slept / 60, experiment_runtime, 100 * already_slept / 60.0 / experiment_runtime))
            if already_slept >= experiment_runtime * 60:
                break
    
        self.log.info("Giving some extra time to memaslap, sleeping for {} minutes.".format(runtime_buffer))
        time.sleep(runtime_buffer * 60)
    
        # region ---- Kill everyone ----
        # Memaslap
        for ms_server in ms_servers:
            ms_server.stop()
    
        # Middleware
        mw_server.stop()
    
        # Memcached
        for mc_server in mc_servers:
            mc_server.stop()
    
        # endregion
    
        # region ---- Download logs, extract data, plot ----
        mw_server.download_logs(local_path=results_dir)
        for ms_server in ms_servers:
            ms_server.download_logs(local_path=results_dir)
    
        # endregion
    
        if hibernate_at_end:
            deployer.hibernate_wait()
    
        self.log.info("Done.")









