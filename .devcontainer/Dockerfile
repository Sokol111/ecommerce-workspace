# syntax=docker/dockerfile:1.7
FROM golang:1.26.5-bookworm

ARG NODE_MAJOR=22
ARG PNPM_VERSION=11.2.2
ARG BUF_VERSION=v1.50.0
ARG PROTOC_GEN_GO_VERSION=v1.36.5
ARG PROTOC_GEN_CONNECT_GO_VERSION=v1.18.1
ARG PROTOC_GEN_GO_GRPC_VERSION=v1.5.1
ARG DELVE_VERSION=v1.27.1
ARG OPENCODE_VERSION=1.17.18
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    GOTOOLCHAIN=local \
    GOBIN=/usr/local/bin \
    CGO_ENABLED=0

# Bake the corporate CA so the DinD daemon trusts it from first start (no update-then-restart race).
COPY ecommerce-infrastructure/environments/local/certs/ca-certificates.crt /usr/local/share/ca-certificates/corporate-ca.crt
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git make gnupg unzip jq bash sudo; \
    update-ca-certificates; \
    rm -rf /var/lib/apt/lists/*

# Non-root user. uid/gid 1000 matches host for writable bind mounts.
RUN set -eux; \
    groupadd --gid ${USER_GID} ${USERNAME}; \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}; \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}; \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Node 22 + pnpm via corepack.
RUN set -eux; \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    corepack enable; \
    corepack prepare pnpm@${PNPM_VERSION} --activate; \
    rm -rf /var/lib/apt/lists/*

# Go CLI tooling (matches services' `make install-tools`).
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg/mod set -eux; \
    go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest; \
    go install golang.org/x/vuln/cmd/govulncheck@latest; \
    go install github.com/securego/gosec/v2/cmd/gosec@latest; \
    go install github.com/psampaz/go-mod-outdated@latest; \
    go install github.com/vektra/mockery/v3@latest; \
    go install github.com/google/go-licenses@latest; \
    go install golang.org/x/tools/cmd/goimports@latest; \
    go install github.com/go-delve/delve/cmd/dlv@${DELVE_VERSION}; \
    go install github.com/bufbuild/buf/cmd/buf@${BUF_VERSION}; \
    go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}; \
    go install connectrpc.com/connect/cmd/protoc-gen-connect-go@${PROTOC_GEN_CONNECT_GO_VERSION}; \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}

# OpenCode CLI. Pin it to the workspace's validated version.
RUN npm install -g opencode-ai@${OPENCODE_VERSION} && npm cache clean --force

RUN mkdir -p /home/${USERNAME}/go /home/${USERNAME}/.config/opencode /home/${USERNAME}/.local/share/opencode && \
    chown -R ${USER_UID}:${USER_GID} /home/${USERNAME}

USER ${USERNAME}
ENV GOPATH=/home/vscode/go \
    PATH=/usr/local/bin:/home/vscode/go/bin:/usr/local/go/bin:$PATH
