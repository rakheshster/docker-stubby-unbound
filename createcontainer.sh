#!/bin/bash
# Usage ./createcontainer.sh <image name> <container name> [ip address] [network name]

# if the first or second arguments are missing give a usage message and exit
if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage ./createcontainer.sh <image name> <container name> [ip address] [network name]"
    exit 1
else
    if [[ -z $(docker image ls -q $1) ]]; then
        # can't find the image, so exit
        echo "Image $1 does not exist"
        exit 1
    else
        IMAGE=$1
    fi

    NAME=$2
fi

if [[ -z "$4" ]]; then 
    # network name not specified, default to bridge
    NETWORK="bridge" 
elif [[ -z $(docker network ls -f name=$4 -q) ]]; then
    # network name specified, but we can't find it, so exit
    echo "Network $4 does not exist"
    exit 1
else
    # passed all validation checks, good to go ahead ...
    NETWORK=$4
fi

if [[ -z "$3" ]]; then
    docker create --name "$NAME" -P --network="$NETWORK" --restart=unless-stopped "$IMAGE"
else
    IP=$3
    docker create --name "$NAME" --ip="$IP" -P --network="$NETWORK" --restart=unless-stopped "$IMAGE"
fi

printf "To start the container do: docker run $NAME"

printf "Creating ${NAME}.service for systemd"
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

printf "Do the following to install this in systemd & enable:"
printf "\tsudo cp ${NAME}.service /etc/systemd/system/"
printf "\tsudo systemctl enable ${NAME}.service"
printf "And if you want to start the service: sudo systemctl start ${NAME}.service"