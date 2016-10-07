import fabric.api
import os

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
        self.PID = None

        fab_settings = dict(
            user=self.ssh_username,
            host_string=self.host_string,
            key_filename=self.ssh_key_filename,
            sudo_password=self.sudo_password
        )

        with fabric.api.settings(**fab_settings):
            print(fabric.api.env)
            print("taivo")
            output = fabric.api.run("ls -la")
            print("taivo2")
            print(type(output))
        print("taivo3")

        # TODO connect to server, make sure everything is installed properly, start memcached

    def update_and_install(self):
        """Update packages and install memcached."""
        # TODO

    def start(self):
        """Start memcached."""
        # TODO
        # TODO also PID variable so we can kill the process later.

    def stop(self):
        """Stop memcached."""
        # TODO


# Testing
if __name__ == "__main__":
    m = Memcached(12345, "pungastforaslvms1.westeurope.cloudapp.azure.com")