import fabric.api
import time
import copy
import re


def server_is_online(ssh_username, ssh_address, ssh_key_filename):
    """Check if we can ssh to the server."""
    try:
        with fabric.api.settings(host_string="{}@{}".format(ssh_username, ssh_address),
                                 user=ssh_username,
                                 key_filename=ssh_key_filename),\
             fabric.api.hide("output", "running"):
            result = fabric.api.run("pwd")

            if result.return_code:
                return False
            else:
                return True
    except Exception as e:
        return False


def wait_for_servers(ssh_username, ssh_address_list, ssh_key_filename, log, check_every_n_sec=20):
    """Wait for all servers in given list to come online."""
    log.info("Checking if all servers are responding to ssh...")
    not_done = copy.deepcopy(ssh_address_list)
    while True:
        not_done = [x for x in not_done if not server_is_online(ssh_username, x, ssh_key_filename)]

        if not_done:
            log.info("Waiting for {} servers to come online, sleeping {} seconds..."
                  .format(len(not_done), check_every_n_sec))
            if len(not_done) == 1:
                log.info("Waiting for {}.".format(not_done[0]))
            time.sleep(check_every_n_sec)
        else:
            log.info("All servers online.")
            break

def server_name_to_number(server_name):
    """'server1' -> 1 etc"""
    regex = re.compile(r"[a-z]*(\d+)")
    return regex.match(server_name).groups()[0]

def is_complete_memaslap_result(filename):
    """Check if memaslap was able to complete in required time."""
    with open(filename) as f:
        for line in f:
            last = line
        if last[0:9] == "Run time:":
            return True
        return False



if __name__ == "__main__":
    print(is_complete_memaslap_result("results/throughput/clients1_threads1_rep0/memaslap7.out"))
    print(is_complete_memaslap_result("results/throughput/clients144_threads4_rep0/memaslap7.out"))
    print(is_complete_memaslap_result("results/trace_rep3/memaslap4.out"))