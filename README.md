# buildkit-docker-in-podman

## On Mac OS
```
podman machine start

podman info

podman info -f json | jq -r '.host.remoteSocket.path'
>>> /run/user/501/podman/podman.sock
```

## Build local container image docker-in-podman-rootless
```
podman build -t skaffold-buildx:0.0.1 -f Containerfile .
podman run -it \
    --net=host \
    --security-opt label=disable \
    -v /run/user/501/podman/podman.sock:/var/run/docker.sock \
    -v /Users/garethrees/gitrepos/buildkit-docker-in-podman:/tmp/mount \
    skaffold-buildx:0.0.1 
```

## Inside podman container

```
cd /tmp/mount

docker pull moby/buildkit:buildx-stable-1
docker tag moby/buildkit:buildx-stable-1 locahost/buildkit:buildx-stable-1

docker run -d --rm \
  --name=remote-buildkitd \
  --privileged \
  --net=host \
  -p 1234:1234 \
  locahost/buildkit:buildx-stable-1 \
  --addr tcp://0.0.0.0:1234

docker buildx create \
  --name remote-container \
  --driver remote \
  --use \
  tcp://localhost:1234

docker buildx ls

skaffold build -f skaffold.yaml
```