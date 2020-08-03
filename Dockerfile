LABEL maintainer="Rakhesh Sasidharan"

################################### BUILDING STUBBY ####################################
FROM alpine:latest AS alpinebuild

ENV GETDNS_VERSION 1.6.0
ENV STUBBY_VERSION 0.3.0

# Get the build-dependencies for stubby & getdns
# See for the official list: https://github.com/getdnsapi/getdns#external-dependencies
# https://pkgs.alpinelinux.org/packages is a good way to search for alpine packages. Note it uses wildcards
RUN apk add --no-cache git build-base \ 
    libtool openssl-dev \
    unbound-dev yaml-dev \
    cmake libidn2-dev libuv-dev libev-dev check-dev \
    && rm -rf /var/cache/apk/*

# Download the source
ADD https://getdnsapi.net/dist/getdns-${GETDNS_VERSION}.tar.gz /tmp/

# Create a workdir called /src, extract the getdns source to that, build it
# NOTE: This builds both getdns and stubby
WORKDIR /src
RUN tar xzf /tmp/getdns-${GETDNS_VERSION}.tar.gz -C ./
WORKDIR /src/getdns-${GETDNS_VERSION}/build
RUN cmake -DBUILD_STUBBY=ON -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && \
    make && \
    make install


################################### THE FINAL IMAGE ####################################
FROM alpine:latest

ENV S6_VERSION 2.0.0.1

# Create a user and group to run stubby as (thanks to https://stackoverflow.com/a/49955098 for syntax)
# addgroup / adduser -S creates a system group / user; the -D says don't assign a password
# Then install the required run-time dependencies (I found these by running stubby and what it complained about)
RUN addgroup -S stubby && adduser -D -S stubby -G stubby && \
    apk add --no-cache unbound-libs yaml libidn2 && \
    mkdir -p /var/cache/stubby && \
    chown stubby:stubby /var/cache/stubby

# Copy the files from the above image to the new image
COPY --from=alpinebuild /usr/local/ /usr/local/

# Copy the config file from $(pwd) to the correct location. Stubby looks for a config file there or at /root/.stubby.yml
COPY stubby.yml /usr/local/etc/stubby/stubby.yml

# Add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / --exclude='./bin' && \
    tar xzf /tmp/s6-overlay-amd64.tar.gz -C /usr ./bin && \
    rm  -f /tmp/s6-overlay-amd64.tar.gz

# s6 overlay doesn't support running as a different user, so am skipping this. I set the stubby service to run under user "stubby" in its service definition though.
# USER stubby:stubby
EXPOSE 8053/udp

ENTRYPOINT ["/init"]

# Credits:
# 1. Thanks to https://github.com/treibholz/docker-stubby/blob/master/Dockerfile

# Notes:
# 1. Stubby is developed by the getdns team. libgetdns is a dependancy for Stubby, the getdns library provides all the core functionality for DNS resolution done by Stubby so it is important to build against the latest version of getdns. 
# 2. Official recommendation (for example: https://github.com/getdnsapi/getdns/releases/tag/v1.6.0) is to get the tarball from getdns than from GitHub
# 3. Cmake steps from https://lektor.getdnsapi.net/quick-start/cmake-quick-start/ (v 1.6.0)