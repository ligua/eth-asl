#!/usr/bin/env bash

LOG_DIR=tmp/local
mkdir -p $LOG_DIR

memcached -p 11211 -t 1 > $LOG_DIR/memcached.out 2>&1 &
MEMCACHED_PID=$!

sleep 2s

ant run > $LOG_DIR/middleware.out &
MIDDLEWARE_PID=$!

sleep 5s

mem/libmemcached-1.0.18/clients/memaslap -s 127.0.0.1:11212 -T 1 -c 1 -o0.9 -S 1s -t 10s -F resources/xlargevalue.cfg > $LOG_DIR/memaslap.out &
MEMASLAP_PID=$!

echo "memcached $MEMCACHED_PID, middleware $MIDDLEWARE_PID, memaslap $MEMASLAP_PID"

sleep 12s

echo `tail -n 1 $LOG_DIR/memaslap.out` | grep --color -e 'TPS: \d\{1,10\}'

kill $MEMASLAP_PID
kill $MEMCACHED_PID
pkill -f java
pkill -f ant