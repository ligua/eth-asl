#!/usr/bin/env bash

NUM_CLIENTS=180

LOG_DIR=tmp/local
mkdir -p $LOG_DIR

rm log/*.log

memcached -p 11211 -t 1 > $LOG_DIR/memcached1.out 2>&1 &
MEMCACHED_PID1=$!
memcached -p 11210 -t 1 > $LOG_DIR/memcached2.out 2>&1 &
MEMCACHED_PID2=$!

sleep 2s

ant run > $LOG_DIR/middleware.out &
MIDDLEWARE_PID=$!

sleep 5s

mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T $NUM_CLIENTS -c $NUM_CLIENTS -o0.9 -S 1s -t 10s -F resources/smallvalue.cfg > $LOG_DIR/memaslap1.out 2>&1 &
MEMASLAP_PID=$!

echo "memcached $MEMCACHED_PID1 $MEMCACHED_PID2, middleware $MIDDLEWARE_PID, memaslap $MEMASLAP_PID"

sleep 20s

echo `tail -n 1 $LOG_DIR/memaslap1.out` | grep --color -e 'TPS: \d\{1,10\}'

kill $MEMASLAP_PID
kill $MEMCACHED_PID1
kill $MEMCACHED_PID2
pkill -f java