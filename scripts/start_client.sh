echo "Starting a memaslap client."

mem/libmemcached-1.0.18/clients/memaslap –s localhost:11212 –T 64 –c 64 –o1 –S 1s –t 1s –F resources/smallvalue.cfg

# mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 1 -c 1 -o1 -S 1s -x 10 -F resources/client_workload.config
# mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 64 -c 64 -o1 -S 1s -t 1m -F resources/client_workload.config
# -s <server>:11212 -T 64 -c 64 -o1 -S 1s -t <time> -F <workloadconfig>