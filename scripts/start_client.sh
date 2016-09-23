echo "Starting a memaslap client."
mem/libmemcached-1.0.18/clients/memaslap -s localhost:11212 -T 64 -c 64 -o1 -S 1s -t 10s # -F <workloadconfig>
# -s <server>:11212 -T 64 -c 64 -o1 -S 1s -t <time> -F <workloadconfig>