amd64:
	docker build --build-arg ARCH=amd64 . -t docker-stubby-unbound:amd64

armhf:
	docker build --build-arg ARCH=armhf . -t docker-stubby-unbound:armhf