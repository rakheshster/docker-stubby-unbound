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

This Stubby + Unbound Docker image packages the two together. It sets up Stubby listening on port 8053 with Unbound listening on port 53 and forwarding to Stubby port 8053.  

## Versions
Version numbers are of the format `<stubby version>-<unbound version>-<patch>` where `<patch>` will be incremented due to changes introduced by me (maybe a change to the `Dockerfile` or underlying Alpine/ s6 base). 

## Configuring
The `root` of this image has the following structure apart from the usual folders. 

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
The `unbound.d` folder is of interest if you want to tweak the Unbound config or add zones etc. All it currently has is a README file and the original `unbound.conf`. Unbound is set to pull in any files ending with `*.conf` from this folder into the running config. 

During runtime a new docker volume can be mapped to this location within the container. Since the new docker volume is empty upon creation, the first time the container is run the contents of `/etc/unbound.d` will be copied from the container to this volume. If you then make any changes to this folder from within the container it will be stored in the docker volume. Of course, you can bind mount a folder from the host too but that will not make visible the existing contents in the image.

You can edit the file via `docker exec` like thus: 
```
docker exec -it stubby-unbound vi /etc/unbound.d/somefile.conf
```

Or you copy a file from outside the container to it:
```
docker cp somefile.conf stubby-unbound:/etc/unbound.d/
```

After making changes reload unload so it pulls in this config. The `/usr/sbin/unbound-reload` script does that. Run it thus:
```
docker exec stubby-unbound unbound-reload
```

### Stubby
Stubby doesn't need any configuring but it would be a good idea to change the upstream DNS servers after downloading this repo and before building the image. 

The Stubby config file is at `/etc/stubby` and during runtime a new docker volume can be mapped to this location within the container (similar to what I do above). Since this volume is empty the first time, the contents of `/etc/stubby` will be copied over to this docker volume and any subsequent changes are stored in the docker volume. Of course, you can bind mount a folder from the host too but that will not make visible the existing contents in the image.

You can edit the config file or copy from outside the container using similar commands as above. 

## Source
The `Dockerfile` can be found in the [GitHub repository](https://github.com/rakheshster/docker-stubby-unbound). 