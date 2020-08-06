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

# create a docker volume for storing data. this is automatically named after the container plus a suffix. 
VOLUME=${NAME}-data
docker volume create $VOLUME

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
    docker create --name "$NAME" \
        -P --network="$NETWORK" \
        --restart=unless-stopped \
        --mount type=volume,source=$VOLUME,target=/etc/unbound.d \
        "$IMAGE"
else
    IP=$3
    docker create --name "$NAME" \
        --ip="$IP" -P \
        --network="$NETWORK" \
        --restart=unless-stopped \
        --mount type=volume,source=$VOLUME,target=/etc/unbound.d \
        "$IMAGE"
fi
# Note that the container already has a /etc/unbound.d folder which contains files copied in during the image build.
# When I create the docker volume above and map it to the container, if this volume is empty the files from within the container are copied over to it.
# Subsequently the files from the volume are used in preference to the files in the image. 

# quit if the above step gave any error
[[ $? -ne 0 ]] && exit 1

printf "\nTo start the container do: \n\tdocker start $NAME"

printf "\n\nCreating ./${NAME}.service for systemd"
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

printf "\n\nDo the following to install this in systemd & enable:"
printf "\n\tsudo cp ${NAME}.service /etc/systemd/system/"
printf "\n\tsudo systemctl enable ${NAME}.service"
printf "\n\nAnd if you want to start the service do: \n\tsudo systemctl start ${NAME}.service \n"