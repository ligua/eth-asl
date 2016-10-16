import fabric.api as fa
import os
import logging


class Memcached(object):
    def __init__(self, serve_port, ssh_hostname,
                 ssh_key_filename=os.path.expanduser("~/.ssh/id_rsa_asl"),
                 ssh_username="pungast",
                 sudo_password="4D0$1QcK5:Nsn:jd!'1j4Uw'j*"):
        self.ssh_hostname = ssh_hostname
        self.ssh_key_filename = ssh_key_filename
        self.ssh_username = ssh_username
        self.sudo_password = sudo_password
        self.host_string = "{}@{}".format(self.ssh_username, self.ssh_hostname)
        self.serve_port = serve_port

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
        """Update packages and install memcached."""
        self.log.info("Updating and installing memcached on machine {}.".format(self.ssh_hostname))
        with fa.settings(**self.fab_settings):
            fa.run("export DEBIAN_FRONTEND=noninteractive")
            fa.run("sudo apt-get --assume-yes update")
            fa.run("sudo apt-get --assume-yes install build-essential libevent-dev memcached")

    def start(self):
        """Start memcached."""
        self.log.info("Before starting, killing previous instances...")
        self.stop()
        self.log.info("Starting memcached on machine {}.".format(self.ssh_hostname))
        with fa.settings(**self.fab_settings):
            command = "memcached -p {} -t 1".format(self.serve_port)
            fa.run("nohup {} > /dev/null 2>&1 &".format(command), pty=False)

            self.log.info("Memcached started.")

    def stop(self):
        """Stops all memcached processes running on that machine."""
        self.log.info("Stopping memcached on machine {}.".format(self.ssh_hostname))
        with fa.settings(**self.fab_settings):
            result = fa.run("pgrep memcached")
            pids = result.split()

            for pid in pids:
                self.log.info("Killing PID={}".format(pid))
                fa.run("sudo kill {}".format(pid))



# Testing
if __name__ == "__main__":
    m = Memcached(11211, "pungastforaslvms1.westeurope.cloudapp.azure.com")
    m.update_and_install()
    m.start()
    input("kil?")
    m.stop()