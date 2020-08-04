#!/bin/bash
if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage ./createcontainer.sh <image name> <container name> <ip address> <network name>"
    exit 1
else
    IMAGE=$1
    NAME=$2
    echo "$IMAGE $NAME"
fi

if [[ -z "$4" ]]; then NETWORK="bridge" else NETWORK=$4

if [[ -z "$3" ]]; then
    docker create --name "$NAME" -P --network="$NETWORK" --restart=unless-stopped "$IMAGE"
else
    IP=$3
    docker create --name "$NAME" --ip="$IP" -P --network="$NETWORK" --restart=unless-stopped "$IMAGE"
fi

echo "Creating $NAME.service for systemd"
cat <<EOF > $NAME.service
    [Unit]
    Description=Stubby Unbound Container
    Requires=docker.service
    After=docker.service

    [Service]
    Restart=always
    ExecStart=/usr/bin/docker start -a $NAME
    ExecStop=/usr/bin/docker stop -t 2 $NAME

    [Install]
    WantedBy=local.target
EOF