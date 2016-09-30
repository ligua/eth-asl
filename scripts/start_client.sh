echo "Starting a memaslap client."

# Official way, 1s
#mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 64 -c 64 -o1 -S 1s -t 1s –F resources/smallvalue.cfg

# Official way, longer
# mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 64 -c 64 -o1 -S 1s -t 20s –F resources/smallvalue.cfg

# Just 2 request generators
mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 2 -c 2 -o1 -S 1s -t 1s –F resources/smallvalue.cfg




# Graveyard
# mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 1 -c 1 -o1 -S 1s -x 10 -F resources/client_workload.config
# mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 64 -c 64 -o1 -S 1s -t 1m -F resources/client_workload.config
# -s <server>:11212 -T 64 -c 64 -o1 -S 1s -t <time> -F <workloadconfig>