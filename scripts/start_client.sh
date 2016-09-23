echo "Starting a memaslap client."
mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 1 -c 1 -o1 -S 1s -x 10 -F conf/client_workload.config

# mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 64 -c 64 -o1 -S 1s -t 10s -F conf/client_workload.config
# -s <server>:11212 -T 64 -c 64 -o1 -S 1s -t <time> -F <workloadconfig>