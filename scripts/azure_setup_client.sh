#!/usr/bin/env bash

username=$1
machine_ssh_address=$2
loadbalancer_address=$3
loadbalancer_port=$4

if [ -z $username ] || [ -z $machine_ssh_address ] || [ -z $loadbalancer_address ]  || [ -z $loadbalancer_port ]
then
echo "Use arguments: username machine_ssh_address loadbalancer_address port"
exit 1
fi

ssh $username@$machine_ssh_address "
    export DEBIAN_FRONTEND=noninteractive
    echo '--- Updating ---'
    sudo apt-get --assume-yes update
    echo '--- Installing required libraries ---'
    sudo apt-get --assume-yes install build-essential libevent-dev
"

echo "--- Building memaslap ---"
if (ssh $username@$machine_ssh_address "[ -f libmemcached-1.0.18/clients/memaslap ]")
then
echo "Memaslap already built."
else
ssh $username@$machine_ssh_address "
    wget https://Launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz
    tar xvf libmemcached-1.0.18.tar.gz
    cd libmemcached-1.0.18
    export LDFLAGS=-lpthread
    ./configure --enable-memaslap && make clients/memaslap
    cd ..
"
fi

ssh $username@$machine_ssh_address "
    ./libmemcached-1.0.18/clients/memaslap -s $loadbalancer_address:$loadbalancer_port -T 64 -c 64 -o1 -S 1s -t 1m
"

# sh scripts/azure_setup_client.sh pungast pungastforaslvms1.westeurope.cloudapp.azure.com 10.0.0.5 11212