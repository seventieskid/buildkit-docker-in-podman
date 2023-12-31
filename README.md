# buildkit-docker-in-podman

Here we illusttrate how to use buildkit with rootful docker INSIDE a rootless podman container.

Instructions are intended for use in a CI/CD pipeline, so must be unique to that pipeline, and are tidied up after use

## On Mac OS (Docker not installed)
```
podman machine start

podman info

podman info -f json | jq -r '.host.remoteSocket.path'
>>> /run/user/501/podman/podman.sock
```

## On MacOS - Build local container image docker-in-podman-rootless
```
podman build -t skaffold-buildx:0.0.1 -f Outer-Containerfile .
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

# We're trying to PREVENT skaffold automaticaly pulling this image,
# So control the pull here (likely to be an internal corporate docker registry)
docker pull moby/buildkit:buildx-stable-1

# Generate a random and unique port to ensure buildkit daemon is listening uniquely on podman host
PORT=$(./get_free_port.sh)

>>> 61545

# Create a standalone buildkit daemon here, it's the only way to provide a service
# for buildkit WITHOUT skaffold or buildx attempt to pull the pre-req container through podman
docker run -d --rm \
  --name=buildkitd-${PORT} \
  --privileged \
  -p ${PORT}:${PORT} \
  moby/buildkit:buildx-stable-1 \
  --addr tcp://0.0.0.0:${PORT}

>>> d237d0ba62c644a30b0b80ccfc1fc0777c494d351659d24cc8218441a92bd205

# On MacOS
podman logs -f d237d0ba62c644a30b0b80ccfc1fc0777c494d351659d24cc8218441a92bd205

# Inside podman container, create a buildx builder for use by skaffold
docker buildx create \
  --name buildx-${PORT} \
  --driver remote \
  tcp://0.0.0.0:${PORT}

docker buildx ls

# Ensures skaffold does not use the default builder
# docker buildx --use doesn't appear to have any affect on skaffold
export BUILDX_BUILDER=buildx-${PORT}

export CR_PAT=ghp_BLAH
export USERNAME=seventieskid

echo $CR_PAT | docker login ghcr.io -u $USERNAME --password-stdin
skaffold build -f skaffold.yaml

  Generating tags...
  - ghcr.io/seventieskid/busybox -> ghcr.io/seventieskid/busybox:cb93d30-dirty
  Checking cache...
  - ghcr.io/seventieskid/busybox: Not found. Building
  Starting build...
  Building [ghcr.io/seventieskid/busybox]...
  #0 building with "buildx-61545" instance using remote driver

  #1 [internal] load build definition from Inner-Dockerfile
  #1 transferring dockerfile: 62B 0.0s done
  #1 DONE 0.0s

  #2 [internal] load metadata for docker.io/library/busybox:1.36.1
  #2 DONE 1.4s

  #3 [internal] load .dockerignore
  #3 transferring context: 2B done
  #3 DONE 0.0s

  #4 [1/1] FROM docker.io/library/busybox:1.36.1@sha256:ba76950ac9eaa407512c9d859cea48114eeff8a6f12ebaa5d32ce79d4a017dd8
  #4 resolve docker.io/library/busybox:1.36.1@sha256:ba76950ac9eaa407512c9d859cea48114eeff8a6f12ebaa5d32ce79d4a017dd8
  #4 resolve docker.io/library/busybox:1.36.1@sha256:ba76950ac9eaa407512c9d859cea48114eeff8a6f12ebaa5d32ce79d4a017dd8 0.0s done
  #4 sha256:a307d6ecc6205dfa11d2874af9adb7e3fc244a429e00e8e3df90534d4cf0f3f8 0B / 2.22MB 0.2s
  #4 sha256:a307d6ecc6205dfa11d2874af9adb7e3fc244a429e00e8e3df90534d4cf0f3f8 2.22MB / 2.22MB 0.3s done
  #4 DONE 0.3s

  #5 importing to docker
  #5 DONE 0.0s

  #6 exporting to docker image format
  #6 exporting layers done
  #6 exporting manifest sha256:51735ec80c2aed973b21c55d6c05a2df6c6f5637d4f7afb6db5defc9642d7c04 0.0s done
  #6 exporting config sha256:9211bbaa0dbd68fed073065eb9f0a6ed00a75090a9235eca2554c62d1e75c58f done
  #6 sending tarball 0.1s done
  #6 DONE 0.4s
  The push refers to repository [ghcr.io/seventieskid/busybox:cb93d30-dirty]
  cb93d30-dirty: digest: sha256:8edd6ab8b09aba74a0d3ab71297a8663385c1b5bf8bb4de0010f928417eee323 size: 502
  Build [ghcr.io/seventieskid/busybox] succeeded

# Stops the temporary buildkit daemon
docker buildx rm buildx-${GIT_COMMIT_SHA}
docker stop buildkitd-${GIT_COMMIT_SHA}
```