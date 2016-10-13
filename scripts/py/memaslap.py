import fabric.api as fa
import os
import logging


class Memaslap(object):
    def __init__(self, ssh_hostname, memcached_hostname, memcached_port,
                 ssh_key_filename=os.path.expanduser("~/.ssh/id_rsa_asl"),
                 ssh_username="pungast",
                 sudo_password="4D0$1QcK5:Nsn:jd!'1j4Uw'j*",
                 id_number=None):
        self.ssh_hostname = ssh_hostname
        self.ssh_key_filename = ssh_key_filename
        self.ssh_username = ssh_username
        self.sudo_password = sudo_password
        self.host_string = "{}@{}".format(self.ssh_username, self.ssh_hostname)
        self.memcached_hostname = memcached_hostname
        self.memcached_port = memcached_port
        self.id_number = id_number

        self.fab_settings = dict(
            user=self.ssh_username,
            host_string=self.host_string,
            key_filename=self.ssh_key_filename,
            sudo_password=self.sudo_password,
            warn_only=True
        )

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

    def update_and_install(self):
        """Update packages and build memaslap."""
        self.log.info("Updating and installing memaslap on machine {}.".format(self.ssh_hostname))
        with fa.settings(**self.fab_settings):
            fa.run("export DEBIAN_FRONTEND=noninteractive")
            fa.run("sudo apt-get --assume-yes update")
            fa.run("sudo apt-get --assume-yes install build-essential libevent-dev")

            result = fa.run("ls libmemcached-1.0.18/clients/memaslap")
            if result.return_code:
                self.log.info("Memaslap not found, building...")
                fa.run("wget https://Launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz")
                fa.run("tar xvf libmemcached-1.0.18.tar.gz")
                fa.run("cd libmemcached-1.0.18; " +
                       "export LDFLAGS=-lpthread; " +
                       "./configure --enable-memaslap && make clients/memaslap; " +
                       "cd ..")
                fa.run("mkdir ~/logs")
                fa.run("mkdir ~/resources")
                fa.local("scp -i {} resources/*.cfg {}:~/resources"
                         .format(self.ssh_key_filename, self.host_string))
            else:
                self.log.info("Memaslap already built.")

    def start(self, concurrency=64, stats_freq="10s", runtime="10s", log_filename="memaslap.out",
              workload_filename="xlargevalue.cfg", verbose=False):
        """Start memaslap."""
        self.log.info("Starting memaslap on machine {}.".format(self.ssh_hostname))
        verbose_string = " -b" if verbose else ""
        with fa.settings(**self.fab_settings):
            command = "./libmemcached-1.0.18/clients/memaslap {} -s {}:{} -T {} -c {} -o0.9 -S {} -t {} -F ~/resources/{}"\
                .format(verbose_string, self.memcached_hostname, self.memcached_port, concurrency, concurrency, stats_freq,
                        runtime, workload_filename)
            fa.run("nohup {} > logs/{} 2>&1 &".format(command, log_filename), pty=False)

            self.log.info("Memaslap started.")

    def stop(self):
        """Stop all memaslap processes running on that machine."""
        self.log.info("Stopping memaslap on machine {}.".format(self.ssh_hostname))
        with fa.settings(**self.fab_settings):
            result = fa.run("pgrep memaslap")
            pids = result.split()

            for pid in pids:
                self.log.info("Killing PID={}".format(pid))
                fa.run("sudo kill {}".format(pid))

    def download_logs(self, local_path="results/baseline"):
        """Download memaslap logs to specified local directory."""
        self.log.info("Downloading memaslap logs from machine {} to {}.".format(self.ssh_hostname, local_path))
        with fa.settings(**self.fab_settings):
            fa.local("mkdir -p {}".format(local_path))
            fa.local("scp -i {} {}:~/logs/*.out {}"
                     .format(self.ssh_key_filename, self.host_string, local_path))

    def clear_logs(self):
        """Clear logs directory."""
        self.log.info("Clearing memaslap logs on machine {}.".format(self.ssh_hostname))
        with fa.settings(**self.fab_settings):
            fa.run("rm ~/logs/*.out")

    def download_built_files(self, local_path="tmp/memaslap"):
        """Download built memaslap files to specified local directory."""
        self.log.info("Downloading built memaslap files from machine {} to {}.".format(self.ssh_hostname, local_path))
        with fa.settings(**self.fab_settings):
            fa.local("mkdir -p {}".format(local_path))
            fa.local("scp -i {} {}:~/libmemcached-1.0.18 {}"
                     .format(self.ssh_key_filename, self.host_string, local_path))

    def upload_built_files(self, local_path="tmp/memaslap/libmemcached-1.0.18"):
        """Upload built memaslap files from specified local directory."""
        self.log.info("Uploading built memaslap files from {} to machine {}.".format(local_path, self.ssh_hostname))
        with fa.settings(**self.fab_settings):
            fa.local("scp -i {} {} {}:~/"
                     .format(self.ssh_key_filename, local_path, self.host_string))

# Testing
if __name__ == "__main__":
    m = Memaslap("pungastforaslvms2.westeurope.cloudapp.azure.com", "10.0.0.4", 11212)
    m.update_and_install()
    m.start()
    input("kil?")
    m.stop()