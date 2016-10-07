import fabric.api as fa
import os
import logging


class Middleware(object):
    def __init__(self, ssh_hostname, serve_hostname, serve_port, num_threads_in_pool, replication_factor,
                 memcached_server_list,
                 ssh_key_filename=os.path.expanduser("~/.ssh/id_rsa_asl"),
                 ssh_username="pungast",
                 sudo_password="4D0$1QcK5:Nsn:jd!'1j4Uw'j*"):
        self.ssh_hostname = ssh_hostname
        self.serve_hostname = serve_hostname
        self.serve_port = serve_port
        self.num_threads_in_pool = num_threads_in_pool
        self.replication_factor = replication_factor
        self.memcached_server_list = memcached_server_list

        self.ssh_key_filename = ssh_key_filename
        self.ssh_username = ssh_username
        self.sudo_password = sudo_password
        self.host_string = "{}@{}".format(self.ssh_username, self.ssh_hostname)

        self.jar_file_name = "middleware-pungast.jar"

        self.fab_settings = dict(
            user=self.ssh_username,
            host_string=self.host_string,
            key_filename=self.ssh_key_filename,
            sudo_password=self.sudo_password,
            warn_only=True
        )

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

    def update_and_install(self):
        """Update packages, copy dependencies and JAR to Azure."""
        with fa.settings(**self.fab_settings):
            fa.run("export DEBIAN_FRONTEND=noninteractive")
            fa.run("sudo apt-get --assume-yes update")
            fa.run("sudo apt-get --assume-yes install openjdk-7-jre")

            # Create directory structure
            fa.run("mkdir -p ~/asl/lib ~/asl/dist")
            fa.run("mkdir -p ~/asl/log")

            # Copy dependencies to server
            fa.local("scp -i {} lib/* {}:~/asl/lib"
                     .format(self.ssh_key_filename, self.host_string))

            # Build JAR locally and copy to server
            fa.local("ant jar")
            fa.local("scp -i {} dist/{} {}:~/asl/dist"
                     .format(self.ssh_key_filename, self.jar_file_name, self.host_string))

    def start(self):
        """Start the middleware."""
        with fa.settings(**self.fab_settings):
            command = "java -classpath lib/ -jar dist/{} -l {} -p {} -t {} -r {} -m {}"\
                .format(self.jar_file_name, self.serve_hostname, self.serve_port,
                        self.num_threads_in_pool, self.replication_factor,
                        Middleware.make_memcached_list_string(self.memcached_server_list))
            fa.run("cd ~/asl; nohup {} > /dev/null 2>&1 &".format(command), pty=False)

            self.log.info("Middleware started.")

    def stop(self):
        """Kill all middleware (Java) processes running on that machine."""
        with fa.settings(**self.fab_settings):
            result = fa.run("pgrep java")
            pids = result.split()

            for pid in pids:
                self.log.info("Killing PID={}".format(pid))
                fa.run("kill {}".format(pid))

    @staticmethod
    def make_memcached_list_string(host_strings):
        """Turn a Python list into the properly formatted string for RunMW to parse."""
        return " ".join(host_strings)

# Testing
if __name__ == "__main__":
    m = Middleware("pungastforaslvms3.westeurope.cloudapp.azure.com", "10.0.0.4", 11212, 1, 1, ["10.0.0.6:11211"])
    m.update_and_install()
    m.start()
    input("kil?")
    m.stop()