#!/bin/sh
# Usage ./createmacvlan.sh <subnet> <gateway> <interface> [network name]

# This is just a script for me to quickly create a macvlan network.

# if the first or second arguments are missing give a usage message and exit
if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
    echo "Usage ./createmacvlan.sh <subnet> <gateway> <interface> [network name]"
    exit 1
else
    SUBNET=$1
    GATEWAY=$2
    INTERFACE=$3
fi

if [[ -z "$4" ]]; then 
    # network name not specified, default to bridge
    NETWORK="my_macvlan_network"
else
    NETWORK=$4
fi

docker network create -d macvlan \
    --subnet="$SUBNET" \
    --gateway="$GATEWAY" \
    -o parent="$INTERFACE" \
    "$NETWORK"