################################### COMMON BUILDIMAGE ####################################
# This image is to be a base where all the build dependencies are installed. 
# I can use this in the subsequent stages to build stuff
FROM alpine:latest AS alpinebuild

# I realized that the build process doesn't remove this intermediate image automatically so best to LABEL it here and then prune later
# Thanks to https://stackoverflow.com/a/55082473
LABEL stage="alpinebuild"
LABEL maintainer="Rakhesh Sasidharan"

# I need the arch later on when downloading s6. Rather than doing the check at that later stage, I introduce the ARG here itself so I can quickly validate and fail if needed.
# Use the --build-arg ARCH=xxx to pass an argument
ARG ARCH=armhf
RUN if ! [[ ${ARCH} = "amd64" || ${ARCH} = "x86" || ${ARCH} = "armhf" || ${ARCH} = "arm" || ${ARCH} = "aarch64" ]]; then \
    echo "Incorrect architecture specified! Must be one of amd64, x86, armhf (for Pi), arm, aarch64"; exit 1; \
    fi

# Get the build-dependencies for everything I plan on building later
# common stuff: git build-base libtool xz cmake
# unbound: expat-dev
# stubby/ getdns: (https://github.com/getdnsapi/getdns#external-dependencies) openssl-dev yaml-dev
# unbound: expat-dev
RUN apk add --update --no-cache \
    git build-base libtool xz cmake \
    openssl-dev yaml-dev libidn2-dev libuv-dev libev-dev check-dev \
    expat-dev
RUN rm -rf /var/cache/apk/*

################################### UNBOUND ####################################
FROM alpinebuild AS alpineunbound

ENV UNBOUND_VERSION 1.11.0

LABEL stage="alpineunbound"
LABEL maintainer="Rakhesh Sasidharan"

# Download the source & build it
ADD https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz /tmp/
WORKDIR /src
RUN tar xzf /tmp/unbound-${UNBOUND_VERSION}.tar.gz -C ./
WORKDIR /src/unbound-${UNBOUND_VERSION}
# Configure to expect everything in / (--prefix=/) but when installing put everything into /usr/local (via DESTDIR=) (I copy the contents of this to / in the final image)
RUN ./configure --prefix=/ 
RUN make && DESTDIR=/usr/local make install

################################### STUBBY ####################################
# This image is to only build Stubby. It builds upon the Unbound image as Stubby needs Unbound libraries. 
FROM alpineunbound AS alpinestubby

ENV GETDNS_VERSION 1.6.0
ENV STUBBY_VERSION 0.3.0

LABEL stage="alpinestubby"
LABEL maintainer="Rakhesh Sasidharan"

# Download the source
# Official recommendation (for example: https://github.com/getdnsapi/getdns/releases/tag/v1.6.0) is to get the tarball from getdns than from GitHub
# Stubby is developed by the getdns team. When building getdns one can also build stubby alongwith
# libgetdns is a dependancy for Stubby, the getdns library provides all the core functionality for DNS resolution done by Stubby so it is important to build against the latest version of getdns.
ADD https://getdnsapi.net/dist/getdns-${GETDNS_VERSION}.tar.gz /tmp/

# Create a workdir called /src, extract the getdns source to that, build it
# Cmake steps from https://lektor.getdnsapi.net/quick-start/cmake-quick-start/ (v 1.6.0)
WORKDIR /src
RUN tar xzf /tmp/getdns-${GETDNS_VERSION}.tar.gz -C ./
WORKDIR /src/getdns-${GETDNS_VERSION}/build
RUN cmake -DBUILD_STUBBY=ON -DCMAKE_INSTALL_PREFIX:PATH=/ ..
RUN make && DESTDIR=/usr/local make install

################################### RUNTIME ENVIRONMENT FOR UNBOUND & STUBBY ####################################
FROM alpine:latest AS alpineruntime

# Get the runtimes deps for all
# stubby (found via running it): yaml libidn2
RUN apk add --update --no-cache ca-certificates \
    yaml libidn2 \
    drill
RUN rm -rf /var/cache/apk/*

# Copy the Stubby & Unbound items from the previous builds into this
# /usr/local/bin -> /bin etc.
COPY --from=alpinestubby /usr/local/ /

# addgroup / adduser -S creates a system group / user; the -D means don't assign a password
RUN addgroup -S unbound && adduser -D -S unbound -G unbound
RUN addgroup -S stubby && adduser -D -S stubby -G stubby
RUN mkdir -p /var/cache/stubby
RUN chown stubby:stubby /var/cache/stubby

################################### S6 & FINALIZE ####################################
# This pulls in Unbound & Stubby, adds s6 and copies some files over
# Create a new image based on alpinebound ...
FROM alpineruntime

# I take the arch (for s6) as an argument. Options are amd64, x86, armhf (for Pi), arm, aarch64. See https://github.com/just-containers/s6-overlay#releases
ARG ARCH=armhf 
LABEL maintainer="Rakhesh Sasidharan"
ENV S6_VERSION 2.0.0.1

# Copy the config files & s6 service files to the correct location
COPY root/ /

# Add s6 overlay. NOTE: the default instructions give the impression one must do a 2-stage extract. That's only to target this issue - https://github.com/just-containers/s6-overlay#known-issues-and-workarounds
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-${ARCH}.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-${ARCH}.tar.gz -C / && \
    rm  -f /tmp/s6-overlay-${ARCH}.tar.gz

# NOTE: s6 overlay doesn't support running as a different user, but I set the stubby service to run under user "stubby" in its service definition.
# Similarly Unbound runs under its own user & group via the config file. 

EXPOSE 8053/udp 53/udp 53/tcp

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s \
    CMD drill @127.0.0.1 -p 8053 google.com || exit 1

ENTRYPOINT ["/init"]