FROM ubuntu:20.04

RUN apt-get update && \
    apt install -y docker.io docker-buildx curl

RUN curl -Lo /usr/local/bin/skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
    chmod 0755 /usr/local/bin/skaffold && \
    skaffold config set --global collect-metrics false && \
    skaffold config set --survey --global disable-prompt true