#!/bin/bash

if [[ $# -ne 4 ]]; then
    echo "Usage ./run.sh <IP Address> <Subnet> <Gateway> <Image Name>";
    echo "Example: ./run.sh 192.168.1.23 192.168.1.0/24 192.168.1.1 rakheshster/docker-stubby-unbound:amd64"
    exit 1
fi

IP=$1
SUBNET=$2
GATEWAY=$3
IMAGE=$4

MACVLAN_NETWORK_NAME="my_macvlan_network"

# create the macvlan network
# I call it my_macvlan_network, point it to my subnet and interface
# I am not excluding any IPs for now as I'll be assigning the container an IP myself
docker network create -d macvlan \
    --subnet="$SUBNET" \
    --gateway="$GATEWAY" \
    -o parent=eth0 \
    $MACVLAN_NETWORK_NAME

docker run -d \
    --name my_stubby-unbound \
    --ip="$IP" \
    -P \
    --network="$MACVLAN_NETWORK_NAME" \
    --restart=unless-stopped \
    "$IMAGE"
