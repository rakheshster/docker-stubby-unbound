#!/bin/bash
# Usage ./buildlocal.sh 

# Not all platforms have all archs if I am building locally. For example M1 Macs don't do linux/386 anymore. 
# ARCH="linux/amd64,linux/arm64,linux/386,linux/arm/v7,linux/arm/v6"
# ARCH="linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6"
ARCH="linux/amd64,linux/arm64"

BUILDINFO="$(pwd)/buildinfo.json"
if ! [[ -r "$BUILDINFO" ]]; then echo "Cannot find $BUILDINFO file. Exiting ..."; exit 1; fi

if ! command -v jq &> /dev/null; then echo "Cannot find jq. Exiting ..."; exit 1; fi

VERSION=$(jq -r '.version' $BUILDINFO)
IMAGENAME=$(jq -r '.imagename' $BUILDINFO)

# delete an existing image of the same name if it exists
# thanks to https://stackoverflow.com/questions/30543409/how-to-check-if-a-docker-image-with-a-specific-tag-exist-locally
if [[ $(docker image inspect ${IMAGENAME} 2>/dev/null) == "" ]]; then
    docker rmi -f ${IMAGENAME}:${VERSION}
fi

docker buildx build --platform $ARCH -t ${IMAGENAME}:${VERSION} -t ${IMAGENAME}:latest --progress=plain .

echo ""
echo "Loading the image of the current architecture (this could fail if I didn't specify it in the ARCH variable earlier)"
docker buildx build --load -t ${IMAGENAME}:${VERSION} -t ${IMAGENAME}:latest .