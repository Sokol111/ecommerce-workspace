# ecommerce

An event-driven, **CQRS** e-commerce platform built as a **multi-repo workspace** of Go
microservices and Nuxt/TypeScript UIs. This root repository is a coordination directory: it
does not contain application code itself, but clones and ties together the independent
`ecommerce-*` repositories, wires the Go services into a single `go.work` workspace, and hosts
both the local and production environments.

> For deep architecture and contributor guidance (used by AI agents and humans alike), see
> [`CLAUDE.md`](CLAUDE.md).

## Repository layout

Each `ecommerce-*` subdirectory is its **own independent git repository** — with its own
`.git`, `LICENSE`, `VERSION`, and release cycle. The root `Makefile` manages them all:

```bash
make setup     # clone every repository listed below
make update    # git pull --rebase in each repository
make status    # git status --short --branch for each repository
make help      # list available root targets
```

Two build ecosystems coexist:

- **Go microservices** — tied together by the root `go.work` (Go 1.26.4 workspace).
- **Nuxt/TypeScript UIs** — each a standalone `pnpm` project.

Because subdirectories are separate repos, **commit and branch per-repo**. A change touching a
service and its API contract is usually two commits in two repos.

## Component map

| Repository | Kind | Responsibility |
|---|---|---|
| `ecommerce-catalog-service` (+ `-api`) | Go service | Write side / source of truth for products, categories, attributes. Emits domain events to Kafka. |
| `ecommerce-product-query-service` (+ `-api`) | Go service | CQRS read model for products, built from catalog Kafka events. |
| `ecommerce-category-query-service` (+ `-api`) | Go service | CQRS read model for categories. |
| `ecommerce-image-service` (+ `-api`) | Go service | Image upload/serving (MinIO + imgproxy). |
| `ecommerce-tenant-service` (+ `-api`) | Go service | Multi-tenancy; consumed by every other service. |
| `ecommerce-commons` | Go library | Shared modules: `core`, `http`, `grpc`, `messaging`, `observability`, `persistence`, `security`, `tenant`, `testutil`. |
| `ecommerce-infrastructure` | Tooling | Deployment for both environments: local dev stack (k3d + Tilt + docker-compose) and production (k3s), plus shared Helm charts and seeders. |
| `ecommerce-ui` | Nuxt UI | Storefront. |
| `ecommerce-admin-ui` | Nuxt UI | Admin console. |
| `ecommerce-platform-ui` | Nuxt UI | Platform console. |

Each `*-api` repo holds the protobuf contract for its service: RPCs under `<name>/v1/` and
Kafka event schemas under `<name>/events/v1/`, with generated Go and TypeScript clients.

## Architecture

- **CQRS + event-driven.** The catalog service owns all writes and publishes events to Kafka.
  Query services consume those events into their own MongoDB read models — they never call the
  catalog service synchronously for data they should be projecting.
- **Hexagonal Go services.** `cmd/main.go` is the composition root; `internal/application/`
  holds domain + use cases; `internal/infrastructure/{inbound,outbound}/` holds adapters
  (Connect-RPC/gRPC, Kafka, MongoDB).
- **Dependency injection** via [`go.uber.org/fx`](https://github.com/uber-go/fx) modules.
- **API contracts** are protobuf, generated with [`buf`](https://buf.build) — edit `.proto`
  and regenerate; never hand-edit `gen/`.
- **Multi-tenancy** is pervasive; tenant context flows through every request.
- **Auth** is JWT validated against a JWKS endpoint (Logto locally).
- **Observability** via OpenTelemetry (local Grafana/Prometheus/Tempo stack).

See [`CLAUDE.md`](CLAUDE.md) for the full architecture deep-dive.

## Prerequisites

- **Go** 1.26.4
- **Node** + **pnpm** (for the UIs)
- Local environment tooling: `k3d`, `kubectl`, `tilt`, `helm`, `docker`

From `ecommerce-infrastructure/environments/local`, run `make tools-check` to verify the local
environment tools are installed.

## Quick start

1. **Clone all repositories** from this root directory:

   ```bash
   make setup
   code ecommerce.code-workspace   # open the multi-root VS Code workspace
   ```

2. **Boot the local environment** from `ecommerce-infrastructure/environments/local`:

   ```bash
   make init      # one-time: create k3d cluster + Traefik + Alloy
   make dev       # Tilt dev mode with hot-reload of all services (also starts Docker infra)
   ```

   Useful lifecycle targets:

   ```bash
   make urls      # print all service + tooling URLs and demo credentials
   make up        # start the cluster and K8s infrastructure (keeps data)
   make down      # stop the cluster (keeps data)
   make clean     # destroy everything (cluster, infra, volumes)
   ```

   Services are exposed via Traefik at `*.127.0.0.1.nip.io`; the Tilt dashboard is at
   [`localhost:10350`](http://localhost:10350).

## Production

The live environment runs on a single **Hetzner VPS with k3s** (namespaces `prod` +
`observability`). Heavy dependencies are **managed external services** rather than self-hosted:
MongoDB Atlas, Cloudflare R2 (object storage), and Grafana Cloud (via an Alloy DaemonSet).
Redpanda, imgproxy, Logto, and Traefik + cert-manager run in-cluster.

- **Deploys are automated CD.** A service release triggers the reusable
  `.github/workflows/deploy.yml`, which `helm upgrade`s the chart into `prod` with the values in
  `environments/production/values/`. Manual `make deploy-svc` is a hotfix fallback.
- **kubectl access is via SSH tunnel** to the k3s API (no public endpoint). From
  `ecommerce-infrastructure/environments/production`, run `make tunnel` (and `make kubeconfig`
  once); then `make status`, `logs SVC=`, `restart SVC=`, `seed TENANT_SLUG=`.
- **Secrets are SOPS-encrypted** (`k8s/secrets.enc.yaml`); edit via `make secrets-edit`.

See [`CLAUDE.md`](CLAUDE.md) and `ecommerce-infrastructure/environments/production/` for details.

## Common commands

Run inside the relevant repository.

**Go services:**

```bash
make run                 # go run ./cmd/main.go
make test                # all tests, -race + coverage
make test-unit           # unit only (-short)
make test-integration    # -tags=integration (real deps via testcontainers)
make lint                # golangci-lint
make check-all           # deps + fmt + lint + test + vuln-check (the CI pipeline)
```

**API repos (`ecommerce-*-api`):**

```bash
make generate            # buf lint + generate Go + TypeScript + event stubs
```

**UIs (`ecommerce-ui`, `ecommerce-admin-ui`, `ecommerce-platform-ui`):**

```bash
pnpm dev                 # nuxt dev
pnpm lint                # eslint
pnpm typecheck           # nuxt typecheck
```

See [`CLAUDE.md`](CLAUDE.md) for the full command reference.

## Release model

Each repo has a `VERSION` file. In **CI/production**, a service consuming an `-api` pins it as a
normal Go module version in `go.mod`, so API changes follow a **release-then-bump** flow: tag
and release the `-api` repo first, then bump the dependency in the consuming service.

**Locally, this does not apply** — everything resolves through the root `go.work`, so a change
in an `-api` repo is visible to its consumers immediately, with no tag/release/`go.mod` bump.

## Dev container

Claude Code can run in an isolated dev container (DinD-sandboxed away from host secrets),
started from the host with:

```bash
make claude              # build (if needed) + run Claude Code inside the container
```

Editing, k3d, and Tilt stay native on the host; only the agent is sandboxed. See
[`.devcontainer/`](.devcontainer/) and [`CLAUDE.md`](CLAUDE.md) for the rationale and details.

## Further documentation

- [`CLAUDE.md`](CLAUDE.md) — full architecture, conventions, and command reference.
- [`LICENSE`](LICENSE) — license terms.
