#!/bin/bash

IP="192.168.17.3"
SUBNET="192.168.17.0/24"
GATEWAY="192.168.17.1"

# create the macvlan network
# I call it my_macvlan_network, point it to my subnet and interface
# I am not excluding any IPs for now as I'll be assigning the container an IP myself
docker network create -d macvlan \
    --subnet="$SUBNET" \
    --gateway="$GATEWAY" \
    -o parent=eth0 \
    my_macvlan_network

docker run -d \
    --name my_stubby-unbound \
    --ip="$IP" \
    --network="my_macvlan_network" \
    --restart=unless-stopped \
    rakheshster/docker-stubby-unbound
