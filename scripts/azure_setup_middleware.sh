#!/usr/bin/env bash

#TODO take as argument the ip of machine where I want to set up middleware, and all information I need for starting middlewaremain
username=$1
machine_ssh_address=$2
machine_local_address=$3
machine_listen_port=$4
number_of_threads_in_pool=$5
replication_factor=$6
memcached_address_and_port=$7

jar_file_name="middleware-pungast.jar"


if [ -z $username ] || [ -z $machine_ssh_address ] || [ -z $machine_local_address ] || [ -z $machine_listen_port ] || [ -z $number_of_threads_in_pool ] || [ -z $replication_factor ] || [ -z $memcached_address_and_port ]
then
echo "Use arguments: username machine_ssh_address machine_local_address machine_listen_port number_of_threads_in_pool replication_factor memcached_address_and_port"
exit 1
fi

# TODO update, install java, upload jar, start middleware

echo "--- Copying dependencies ---"
ssh $username@$machine_ssh_address "mkdir -p ~/asl/lib ~/asl/dist"
scp lib/* $username@$machine_ssh_address:~/asl/lib

echo "--- Copying JAR ---"
scp dist/$jar_file_name $username@$machine_ssh_address:~/asl/dist


ssh $username@$machine_ssh_address "
    export DEBIAN_FRONTEND=noninteractive
    echo '--- Updating ---'
    sudo apt-get update
    echo '--- Installing OpenJDK ---'
    sudo apt-get install openjdk-7-jre
    echo '--- Copying JAR ---'
    cd ~/asl
    java -classpath lib/ -jar dist/$jar_file_name -l $machine_local_address -p $machine_listen_port -t $number_of_threads_in_pool -r $replication_factor -m $memcached_address_and_port
"





# sh scripts/azure_setup_middleware.sh pungast pungastforaslvms3.westeurope.cloudapp.azure.com 10.0.0.6 11211 1 1 10.0.0.5:11212