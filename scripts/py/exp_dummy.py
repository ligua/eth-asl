import logging
from experiment import Experiment

# region ---- Logging ----
LOG_FORMAT = '%(asctime)-15s [%(name)s] - %(message)s'
LOG_LEVEL = logging.INFO
formatter = logging.Formatter(LOG_FORMAT)

ch = logging.StreamHandler()
ch.setLevel(LOG_LEVEL)
ch.setFormatter(formatter)

log = logging.getLogger(__name__)
log.setLevel(LOG_LEVEL)
log.addHandler(ch)
# endregion

# region ---- Experimental setup ----
S_values = [3, 4, 5, 6, 7]              # number of servers
R_lambdas = [lambda S: 1, lambda S: S]   # replication factor
workload_values = [0.01, 0.05, 0.10]    # workload write proportion

experiment_runtime = 15

# endregion
for S in S_values:
    for R_lambda in R_lambdas:
        R = R_lambda(S)
        for workload in workload_values:
            log.info("Starting experiment with S={}, R={}, workload={}".format(S, R, workload))


