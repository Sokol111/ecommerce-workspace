# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

This is a **multi-repo workspace**, not a single project. The root is a coordination
directory: each `ecommerce-*` subdirectory is its own independent git repository (each has
its own `.git`, `LICENSE`, `VERSION`, and release cycle). The root `Makefile` clones/pulls
them all via `make setup` / `make update` / `make status`.

Two build ecosystems coexist:
- **Go microservices** — tied together by the root `go.work` (Go 1.26.4 workspace).
- **Nuxt/TypeScript UIs** — each a standalone pnpm project.

Because subdirectories are separate repos, commit and branch per-repo. A change touching a
service and its API contract is usually **two commits in two repos** (the `*-api` repo must be
tagged/released before the consuming service can bump its dependency).

**Release-then-bump applies to production/CI only — not to local development.** Locally
everything resolves through the root `go.work`, so a change in an `-api` repo is visible to
its consumers immediately, with no tag/release/`go.mod` bump. This also holds when building
images for the local k8s cluster: `Dockerfile.go` ignores the pinned `go.mod` versions and
instead reconstructs a `go.work` inside the image from the local sources — Tilt passes the
list of api dirs via the `API_DEPS` build arg (see `api_deps` in the local `Tiltfile`), and
the Dockerfile `go work use`s each copied api module. So local api changes flow into the
image through the workspace too, exactly like local `make run`.

## Where Claude Code runs

Claude Code for this workspace runs in one of two places — check which one you're in before
assuming host tooling (k3d, Tilt, docker-compose) is reachable:

- **WSL host** (`/home/ihsokolo/projects/ecommerce`) — normal interactive use, prompts for
  permission as usual. This is where `make dev`/`make up` (k3d + Tilt) must be run; the local
  cluster is host-only and is NOT reachable from the devcontainer.
- **Dev container** (`/workspaces/ecommerce`, see `.devcontainer/`) — runs in autonomous
  bypass mode (`permissions.defaultMode: bypassPermissions`), started via `make claude` from
  the host. It exists to sandbox the bypass agent away from host secrets (WSL-stored tokens,
  sops secrets): its `~/.claude` is a named Docker volume, not a bind-mount of the host's, so
  it never sees host credentials or the host's global MCP servers/`~/.claude.json`. The
  workspace itself (all `ecommerce-*` repos) is bind-mounted, not copied, so edits are live in
  both places instantly. Scope inside the container is toolchain + tests only (build, test,
  lint, generate, `go.work`) via Docker-in-Docker for testcontainers — no k3d/Tilt stack there.

To tell which one you're in: `pwd` will show `/workspaces/ecommerce` in the container vs
`/home/ihsokolo/projects/ecommerce` on the host; `[ -f /.dockerenv ]` is also a reliable check.

## Component map

Services (Go), each paired with an `-api` contract repo:
- `ecommerce-catalog-service` (+ `-api`) — write side / source of truth for products,
  categories, attributes. Emits domain events to Kafka.
- `ecommerce-product-query-service` (+ `-api`) — read model for products (CQRS query side),
  built by consuming catalog Kafka events.
- `ecommerce-category-query-service` (+ `-api`) — read model for categories.
- `ecommerce-image-service` (+ `-api`) — image upload/serving (MinIO + imgproxy).
- `ecommerce-tenant-service` (+ `-api`) — multi-tenancy; consumed by every other service.

Shared / support:
- `ecommerce-commons` — shared Go library (`pkg/core`, `http`, `grpc`, `messaging`,
  `observability`, `persistence`, `security`, `tenant`, `testutil`). Wired as `fx` modules.
- `ecommerce-infrastructure` — local dev stack (k3d + Tilt + docker-compose), Helm charts,
  seeders (`cmd/seeder`, `cmd/logto-seed`).
- `ecommerce-ui` (storefront), `ecommerce-admin-ui`, `ecommerce-platform-ui` — Nuxt apps.

## Architecture

**CQRS + event-driven.** The catalog service owns writes and publishes events to Kafka; the
query services consume those events into their own MongoDB read models. Never make a query
service call the catalog service synchronously for data it should be projecting from events.

**Hexagonal layout** inside each Go service:
- `cmd/main.go` — composition root. Assembles the app from `fx.Options` modules only; no
  business logic. This is the best file to read first to understand a service's wiring.
- `internal/application/<aggregate>/` — domain + use cases (e.g. `product/`, `category/`).
  Command handlers (`create_product.go`), query handlers, `repository.go` (port interface),
  `errors.go`, `event_factory.go`. Mocks (`mock_*.go`) are generated here.
- `internal/infrastructure/inbound/` — adapters driving the app: `connect/` (Connect-RPC /
  gRPC handlers), `kafka/` (event consumers, on query services).
- `internal/infrastructure/outbound/` — adapters the app drives: `mongo/` (repository impls,
  `*_entity.go` + `*_mapper.go`), `kafka/` (event producers, on catalog).

**Dependency injection is `go.uber.org/fx`.** Every package exposes a `Module()` /
`New*Module()` returning `fx.Options`. To add a component, provide it in the relevant module
rather than constructing it manually in `main.go`.

**API contracts are protobuf, generated with `buf`.** In each `*-api` repo, `proto/` holds
`.proto` sources (service RPCs under `<name>/v1/`, Kafka event schemas under
`<name>/events/v1/`). `make generate` produces Go (`gen/go`, published as the Go module) and
TypeScript (`gen/typescript`, consumed by the Nuxt UIs). **Edit `.proto` and regenerate — never
hand-edit files under `gen/`.**

## Common commands

### Go services (run inside a service directory)
```bash
make run                 # go run ./cmd/main.go
make build               # build binary into bin/ (injects VERSION via -ldflags)
make test                # all tests, -race + coverage
make test-unit           # -short (unit only)
make test-integration    # -tags=integration (spins up real deps, e.g. Mongo via testcontainers)
make test-e2e            # -tags=e2e (requires a running service)
make lint                # golangci-lint
make fmt                 # gofmt -s + goimports
make generate-mocks      # mockery (config: .mockery.yaml)
make check-all           # deps + fmt + lint + test + vuln-check (the CI pipeline)
make install-tools       # install golangci-lint, mockery, govulncheck, etc.
```
Run a single test: `go test ./internal/application/product/ -run TestCreateProduct -v`

### API repos (`ecommerce-*-api`)
```bash
make generate            # buf lint + generate Go + TypeScript + event stubs
make lint                # buf lint
```

### UIs (`ecommerce-ui`, `ecommerce-admin-ui`, `ecommerce-platform-ui`) — pnpm
```bash
pnpm dev                 # nuxt dev
pnpm build
pnpm lint                # eslint
pnpm typecheck           # nuxt typecheck
pnpm link:local          # link locally-generated *-api TS clients (for cross-repo dev)
```

### Local environment (`ecommerce-infrastructure/environments/local`)
Requires: `k3d kubectl tilt helm docker`. Check with `make tools-check`.
```bash
make init                # one-time: create k3d cluster + Traefik + Alloy
make docker              # start Mongo, Kafka (Redpanda), MinIO, Logto, observability
make dev                 # Tilt dev mode with hot-reload of all services
make up / make down      # start / stop the cluster (keeps data)
make urls                # print all service + tooling URLs and demo credentials
make clean               # destroy everything (cluster, infra, volumes)
```
Services are exposed via Traefik at `*.127.0.0.1.nip.io`; Tilt dashboard at `localhost:10350`.

## Cross-cutting conventions

- **Multi-tenancy is pervasive.** `ecommerce-commons/pkg/tenant` and `tenant-service-api`
  modules are wired into every service's `main.go`. Tenant context flows through requests;
  respect it in new repository queries and handlers.
- **Auth** is JWT validated against a JWKS endpoint (Logto locally). Config under `security.jwks`.
- **Config** is YAML per service under `configs/` (e.g. `config.standalone.yaml`), overridable
  by env/`.env`. Covers `mongo`, `kafka`, `security`, `logger`, `observability`.
- **Observability**: OpenTelemetry tracing/metrics via `commons/pkg/observability`; local
  Grafana/Prometheus/Tempo stack.
- **Versioning**: each repo has a `VERSION` file; a service consuming an `-api` pins it as a
  normal Go module version in `go.mod`, so API changes require release-then-bump.
