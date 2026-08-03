---
name: go-upgrade
description: Use when upgrading Go across this workspace. Updates Go installation, go.mod and go.work files, Dockerfiles, workflows, and Go development tools.
---

# Go Version Upgrade

Upgrade Go to the latest stable version or a user-specified target across the
entire workspace.

## Procedure

### 1. Determine the target version

1. Use the version explicitly provided by the user.
2. Otherwise, fetch the latest stable version from `https://go.dev/dl/?mode=json`.
3. Confirm the target version with the user before making changes.

### 2. Install Go

Detect how Go is currently installed with `which go`, then decide how to update
it. **Do not silently install Go into a user-local directory (for example
`$HOME/.local/go`) just to avoid privileges**: this leaves the system Go
unchanged and breaks tools such as VS Code, which resolve `go` from the default
`PATH` (`/usr/local/go/bin/go`).

Use the same installation method that is already in place:

- `/usr/local/go/bin/go`: this is the official tarball installation and lives in
  a system directory. It requires `sudo` to replace. **Before touching
  `/usr/local/go`, ask the user for explicit permission** and explain that it is
  a system-wide change. If the user approves, run the standard tarball replace
  (`rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz`). If the user does
  not approve or sudo is unavailable, stop and provide exact manual commands for
  the user to run rather than creating a local-only copy.
- Homebrew (`/opt/homebrew/...` or `/usr/local/Cellar/...`): run `brew upgrade go`.
- apt or snap: use the corresponding package manager.
- goenv or asdf: use that version manager.
- Dev container (`/workspaces/ecommerce`): the Go toolchain is usually provided
  by the container image. Ask the user whether to update the base image /
  devcontainer configuration instead of mutating the container filesystem.

After any installation step, verify the default Go on `PATH` (not just inside a
shell where `PATH` was manually overridden):

```bash
go version
which go
```

If `go version` still reports the old version, the installation did not update
the binary that the rest of the tooling sees. Do not continue until `go version`
matches the target.

### 3. Update Go workspace files

Find and update every `go.work` file in the workspace.

### 4. Update module files

Find every `go.mod` file and, in each module directory, run:

```bash
go mod edit -go=<target_version>
go mod tidy
```

`go mod tidy` can fail in services importing local packages from
`ecommerce-commons` that have not been published. The root `go.work` resolves
these locally, so record the failure but do not treat it as a blocker after the
`go mod edit` change has succeeded.

### 5. Update Dockerfiles

Update **every** Dockerfile that references the Go toolchain in the workspace.
There are three independent sets:

1. Release build Dockerfiles in the infrastructure repo:
   - `ecommerce-infrastructure/docker/Dockerfile.go`
   - `ecommerce-infrastructure/docker/Dockerfile.seeder`
   - `ecommerce-infrastructure/docker/Dockerfile.logto-seed`

2. Local dev/Tilt Dockerfiles (also in the infrastructure repo):
   - `ecommerce-infrastructure/environments/local/docker/Dockerfile.go`
   - `ecommerce-infrastructure/environments/local/docker/Dockerfile.seeder`
   - `ecommerce-infrastructure/environments/local/docker/Dockerfile.logto-seed`

3. Dev container image (workspace root):
   - `.devcontainer/Dockerfile`

In each file:

- Update every `golang:<version>` image reference.
- Update `ARG DELVE_VERSION=...` (if present) and any
  `go install github.com/go-delve/delve/cmd/dlv@<version>` with the
  concrete Delve version resolved below.

Never replace the pinned Delve version with `@latest` in a Dockerfile.

Resolve the Delve version first by fetching the latest release from
`https://api.github.com/repos/go-delve/delve/releases/latest`.

### 6. Update GitHub workflows

Search `ecommerce-infrastructure/.github/workflows/` for `go-version`.

- Replace full versions such as `'1.26.2'` with the target full version.
- Replace major.minor versions such as `'1.26'` only when the target minor
  version differs. Do not change them for a patch-only update.

### 7. Reinstall Go tools

Reinstall all tools so they are compiled with the new toolchain:

```bash
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go install github.com/vektra/mockery/v3@latest
go install golang.org/x/vuln/cmd/govulncheck@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/psampaz/go-mod-outdated@latest
go install github.com/google/go-licenses@latest
go install github.com/securego/gosec/v2/cmd/gosec@latest
go install github.com/ogen-go/ogen/cmd/ogen@latest
go install github.com/daveshanley/vacuum@latest
go install github.com/hamba/avro/v2/cmd/avrogen@latest
```

Record the outcome of each installation.

### 8. Verify

1. Check the installed version: `go version`.
2. Check all `go.mod` and `go.work` Go directives.
3. Confirm Dockerfiles use the target Go version and the resolved Delve version.
4. Confirm workflow `go-version` values follow the version-format rules.
5. Run `go build ./...` and `go test ./...` from the workspace root.
6. Report the installed Go version; updated `go.work`, `go.mod`, Dockerfile,
   and workflow counts; Delve version; tool-install results; build result; and
   test result.
