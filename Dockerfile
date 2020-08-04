################################### BUILDING STUBBY ####################################
# This image is to only build Stubby
FROM alpine:latest AS alpinebuild

ENV GETDNS_VERSION 1.6.0
ENV STUBBY_VERSION 0.3.0

# I need the arch later on when downloading s6. Rather than doing the check at that later stage, I introduce the ARG here itself so I can quickly validate and fail if needed.
# Use the --build-arg ARCH=xxx to pass an argument
ARG ARCH=armhf
RUN if ! [[ ${ARCH} = "amd64" || ${ARCH} = "x86" || ${ARCH} = "armhf" || ${ARCH} = "arm" || ${ARCH} = "aarch64" ]]; then \
    echo "Incorrect architecture specified! Must be one of amd64, x86, armhf (for Pi), arm, aarch64"; exit 1; \
    fi

# Get the build-dependencies for stubby & getdns
# See for the official list: https://github.com/getdnsapi/getdns#external-dependencies
# https://pkgs.alpinelinux.org/packages is a good way to search for alpine packages. Note it uses wildcards
RUN apk add --update --no-cache git build-base \ 
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
# This image contains Unbound, s6, and I copy the Stubby files from above into it.
FROM alpine:latest

# I take the arch (for s6) as an argument. Options are amd64, x86, armhf (for Pi), arm, aarch64. See https://github.com/just-containers/s6-overlay#releases
ARG ARCH=armhf 
LABEL maintainer="Rakhesh Sasidharan"
ENV S6_VERSION 2.0.0.1

# Install Unbound (first line) and run-time dependencies for Stubby (I found these by running stubby and what it complained about)
# Also create a user and group to run stubby as (thanks to https://stackoverflow.com/a/49955098 for syntax)
# Unbound doesn't need a user/ group as the package automatically creates one
# addgroup / adduser -S creates a system group / user; the -D says don't assign a password
RUN apk add --update --no-cache unbound ca-certificates \
    unbound-libs yaml libidn2 \
    drill && \
    addgroup -S stubby && adduser -D -S stubby -G stubby && \
    mkdir -p /var/cache/stubby && \
    chown stubby:stubby /var/cache/stubby

# Copy the files from the above image to the new image (so /usr/local/bin -> /bin etc.)
COPY --from=alpinebuild /usr/local/ /

# Copy the config files & s6 service files to the correct location
COPY etc/ /etc/

# Add s6 overlay. NOTE: the default instructions give the impression one must do a 2-stage extract. That's only to target this issue - https://github.com/just-containers/s6-overlay#known-issues-and-workarounds
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-${ARCH}.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-${ARCH}.tar.gz -C / && \
    rm  -f /tmp/s6-overlay-${ARCH}.tar.gz

# s6 overlay doesn't support running as a different user, so am skipping this. I set the stubby service to run under user "stubby" in its service definition though.
# USER stubby:stubby
# USER unbound:unbound

EXPOSE 8053/udp 53/udp 53/tcp

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s \
    CMD drill @127.0.0.1 -p 8053 google.com || exit 1

ENTRYPOINT ["/init"]

# Credits:
# 1. Thanks to https://github.com/treibholz/docker-stubby/blob/master/Dockerfile

# Notes:
# 1. Stubby is developed by the getdns team. libgetdns is a dependancy for Stubby, the getdns library provides all the core functionality for DNS resolution done by Stubby so it is important to build against the latest version of getdns. 
# 2. Official recommendation (for example: https://github.com/getdnsapi/getdns/releases/tag/v1.6.0) is to get the tarball from getdns than from GitHub
# 3. Cmake steps from https://lektor.getdnsapi.net/quick-start/cmake-quick-start/ (v 1.6.0)
