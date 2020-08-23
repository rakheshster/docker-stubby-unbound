# Stubby + Unbound + Docker
## First things first
It is best to target a specific release when pulling this repo. Either switch to the correct tag after downloading, or download a zip of the latest release from the [Releases[(https://github.com/rakheshster/docker-stubby-unbound/releases) page. 

We are currently at v0.2.1 and contain the following:
  * Alpine 3.12 & s6-overlay 2.0.0.1 (via my [alpine-s6](https://hub.docker.com/repository/docker/rakheshster/alpine-s6) image)
  * Stubby 0.3.0 & GetDNS 1.6.0
  * Unbound 1.11.0

I had a v0.1 pushed to GitHub before I started thinking about how to properly version these. In the vein of [Semantic Versioning](https://semver.org) the version numbers starting with v0.2.0 of this image is in a MAJOR.MINOR.PATCH format and currently at the number above. 

  * I will update PATCH when I make any changes to the Dockerfile or config files etc. These will be minor behind the scene changes introduced by me. 
  * I will update MINOR in case of any minor updates to any of the software above. For example: Stubby 0.3.1 will be a minor update. 
  * And I will update MAJOR in case of major updates to any of the software above. For example: Unbound 1.12 or Alpine 3.xx would be a major update. 

## What is this?
This is a Docker image containing Stubby and Unbound. 

From the [Stubby documentation](https://dnsprivacy.org/wiki/display/DP/DNS+Privacy+Daemon+-+Stubby):
> Stubby is an application that acts as a local DNS Privacy stub resolver (using DNS-over-TLS). Stubby encrypts DNS queries sent from a client machine (desktop or laptop) to a DNS Privacy resolver increasing end user privacy.

As of version 0.3 Stubby also supports DNS-over-HTTPs.

From the [Unbound documentation](https://nlnetlabs.nl/projects/unbound/about/):
> Unbound is a validating, recursive, caching DNS resolver. It is designed to be fast and lean and incorporates modern features based on open standards. To help increase online privacy, Unbound supports DNS-over-TLS which allows clients to encrypt their communication. 

Unbound is both a DNS server and a resolver. It is useful if you want a DNS server for home DNS resolution for instance (which was my use case, for my home lab).

From the [DNS Privacy Project](https://dnsprivacy.org/wiki/display/DP/About+Stubby):
> Unbound can be configured as a local forwarder using DNS-over-TLS to forward queries. However at the moment Unbound does not have all the TCP/ TLC features that Stubby has for example, it cannot support ‘Strict’ mode, it cannot pad queries to hide query size and it opens a separate connection for /every/ DNS query (Stubby will re-use connections). However, Unbound is a mature and stable daemon and many people already use it as a local resolver. 

It is possible to combine both together though - i.e. use Unbound as your DNS resolver, forwarding to Stubby running on a different port that does the actual DNS resolution using DNS-over-TLS. A sample config for this scenario can be found on [this page](https://dnsprivacy.org/wiki/display/DP/DNS+Privacy+Clients#DNSPrivacyClients-Unbound/Stubbycombination). 

This Stubby + Unbound Docker image packages the two together. It sets up Stubby listening on port 8053 with Unbound listening on port 53 and forwarding to Stubby port 8053. I use NextDNS, so the Stubby config points to NextDNS currently but you can change it (_and should do so as it currently uses my configuration ID_). 

## s6-overlay
I also took the opportunity to setup an [s6-overlay](https://github.com/just-containers/s6-overlay). I like their philosophy of a Docker container being “one thing” rather than “one process per container”. This is why I chose to create one image for both Stubby & Docker instead of separate images. It was surprisingly easy to setup. 

The `etc` folder contains a `services.d` folder that holds the service definitions for Stubby and Unbound. Unbound is set to depend on Stubby via a `dependencies` file so they start in the correct order. The config files and service definitions are intentionally set to run Stubby and Unbound in the foreground. That’s because s6 expects them to run in the foreground. Moreover, each service runs under a separate non-root user account. 


## Configuring
The `root` folder has the following structure. 

```
root
├── etc
│   ├── services.d
│   │   ├── stubby
│   │   │   └── run
│   │   └── unbound
│   │       ├── dependencies
│   │       └── run
│   ├── stubby
│   │   ├── stubby.orig.yml
│   │   └── stubby.yml
│   ├── unbound
│   │   └── unbound.conf
│   └── unbound.d
│       ├── README.txt
│       └── unbound.conf.orig
└── usr
    └── sbin
        └── unbound-reload
```

### Unbound
The `unbound.d` folder is of interest if you want to tweak the Unbound config or add zones etc. All it currently has is a README file and the original `unbound.conf`. When the image is built the contents of this folder are copied into it at `/etc/unbound.d`, but during runtime a new docker volume and mapped to this location *within the container*. Since the new docker volume is empty upon creation, the first time the container is run the contents of `/etc/unbound.d` are copied from the container to this volume. If you then make any changes to this folder from within the container it will be stored in the docker volume. 

Unbound is set to pull in any files ending with `*.conf` from this folder into the running config. 

You can edit the file via `docker exec` like thus: 
```
docker exec -it pi1_docker-stubby-unbound vi /etc/unbound.d/somefile.conf
```

Or you copy a file from outside the container to it:
```
docker cp somefile.conf pi1_docker-stubby-unbound:/etc/unbound.d/
```

After making changes reload unload so it pulls in this config. The `/usr/sbin/unbound-reload` script does that. Run it thus:
```
docker exec pi1_docker-stubby-unbound unbound-reload
```

### Stubby
Stubby doesn't need any configuring but it would be a good idea to change the upstream DNS servers after downloading this repo and before building the image. 

When the image is built the `stubby` folder is copied into it at `/etc/stubby`, but during runtime a new docker volume is created and mapped to this location within the container (similar to what I do above). Since this volume is empty the first time, the contents of `/etc/stubby` are copied over to this docker volume but any subsequent changes its contents are stored in the docker volume. 

You can edit the config file or copy from outside the container using similar commands as above. 

## Building & Running
The quickest way to get started after cloning/ downloading this repo is to use the `./buildlocal.sh` file. It takes a single optional argument - the name you want to give the image (defaults to `rakheshster/stubby-unbound`).

NOTE: the script is optional. You can build this via `docker build` too. And additional script `./buildandpush.sh` is what I use to create multi-arch images and push to Docker Hub. It too is optional. 

After the image is built you can run it manually via `docker run` or you use the `./createcontainer.sh` script which takes the image name and container name as mandatory parameters and optionally the IP address and network of the container. I tend to use a macvlan network to run this so the container has its own IP address on my network. 

### Systemd integration
The `./createcontainer.sh` script doesn’t run the container. It creates the container and also creates a systemd service unit file along with some instructions on what to do with it. This way you have systemd managing the container so it always starts after a system reboot. The unit file and systemd integration is optional of course; I wanted the container to always start after a reboot as it provides DNS for my home lab and is critical, that’s why I went through this extra effort. 

Note: The service unit file is set to only restart if the service is aborted. This is intentional in case you want to `docker stop` the container sometime. 

## Notes
This is my first Docker image. 

Thanks to [GitHub - MatthewVance/stubby-docker: Gain the full power of DNS-over-TLS forwarding by combining Stubby with Unbound](https://github.com/MatthewVance/stubby-docker) and [GitHub - treibholz/docker-stubby: minimal alpine-linux based stubby](https://github.com/treibholz/docker-stubby) which I referred to extensively to pick up Docker as I went along. Any mistakes or inefficiencies in this Docker image are all mine. 
