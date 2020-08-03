default:
	@echo "You need to specify one of these a target: amd64, x86, armhf (for Pi), arm, aarch64"

amd64 x86 armhf arm aarch64:
	docker build --build-arg ARCH=$@ . -t rakheshster/docker-stubby-unbound:$@