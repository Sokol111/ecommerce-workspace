---
name: go-upgrade
description: 'Upgrade Go to the latest version across the entire workspace. Updates go.mod, go.work, Dockerfiles (including dlv), GitHub workflows, and reinstalls/recompiles all Go tools.'
argument-hint: 'Optionally specify target Go version, e.g. "1.27.0"'
disable-model-invocation: true
---

# Go Version Upgrade

Upgrade Go to the latest (or specified) version across the entire workspace.

## Procedure

### Step 1: Determine Target Go Version

1. If the user specified a version, use that
2. Otherwise, fetch the latest stable version from https://go.dev/dl/?mode=json
3. Confirm the target version with the user before proceeding

### Step 2: Install the New Go Version

**Important:** Detect how Go is currently installed (`which go`) and use the same method to update. Do NOT use package managers if Go was installed from the official tarball.

1. Detect installation path via `which go`
2. Update Go using the same method it was originally installed:
   - `/usr/local/go/bin/go` → download tarball from `https://go.dev/dl/` and replace `/usr/local/go`
   - Homebrew (`/opt/homebrew/...` or `/usr/local/Cellar/...`) → `brew upgrade go`
   - apt/snap → use the corresponding package manager
   - goenv/asdf → use the version manager to install the new version
3. Verify with `go version`

### Step 3: Update go.work Files

Find and update **all** `go.work` files in the workspace.

### Step 4: Update go.mod Files

Find and update **all** `go.mod` files in the workspace. Use `go mod edit -go=<target_version>` and then `go mod tidy` in each module directory.

**Note:** In this workspace, `go mod tidy` will fail for services that import local packages from `ecommerce-commons` not yet published to the remote registry. This is expected — the `go.work` file handles local module resolution. The `go mod edit -go=<version>` change is still applied successfully. Do not treat these `go mod tidy` failures as blockers.

### Step 5: Update Dockerfiles

Update Go image tags and dlv version in all Dockerfiles under `ecommerce-infrastructure/docker/`.

- Update `golang:<version>` image references to the new Go version
- Fetch the latest dlv release from https://api.github.com/repos/go-delve/delve/releases/latest and update `go install github.com/go-delve/delve/cmd/dlv@<version>`

**Important:** Dockerfiles use a pinned dlv version (e.g. `@v1.26.3`), NOT `@latest`. Always resolve the concrete latest version from the GitHub API and pin it explicitly.

### Step 6: Update GitHub Workflows

Search for `go-version` in all workflow files under `ecommerce-infrastructure/.github/workflows/` and update version references.

**Version format rules:**
- Workflows with full version (e.g. `'1.26.2'`) → update to new full version (e.g. `'1.26.3'`)
- Workflows with major.minor only (e.g. `'1.26'`) → only update when the minor version changes (e.g. `1.25` → `1.26`). Do NOT change for patch-only updates within the same minor series.

### Step 7: Update and Reinstall Go Tools

Reinstall all Go tools to compile with the new Go version. Even if using `@latest`, reinstalling ensures they are compiled with the new Go toolchain.

```bash
# Core development tools
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go install github.com/vektra/mockery/v3@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

# Debugger
go install github.com/go-delve/delve/cmd/dlv@latest

# Analysis tools
go install github.com/psampaz/go-mod-outdated@latest
go install github.com/google/go-licenses@latest
go install github.com/securego/gosec/v2/cmd/gosec@latest

# Code generation tools
go install github.com/ogen-go/ogen/cmd/ogen@latest
go install github.com/daveshanley/vacuum@latest
go install github.com/hamba/avro/v2/cmd/avrogen@latest
```

Verify each installation was successful by checking the exit code.

### Step 8: Verification

Run the verification checklist:

1. **Go version check**:
   ```bash
   go version
   ```

2. **All go.mod files have new version**:
   ```bash
   echo "=== go.mod version check ===" && \
   find . -name 'go.mod' -not -path '*/vendor/*' -exec grep -H '^go ' {} \;
   ```

3. **All go.work files have new version**:
   ```bash
   echo "=== go.work version check ===" && \
   find . -name 'go.work' -exec grep -H '^go ' {} \;
   ```

4. **Dockerfiles have new version**:
   ```bash
   echo "=== Dockerfile version check ===" && \
   grep -rn 'golang:' ecommerce-infrastructure/docker/Dockerfile.* | grep -v '#'
   ```

5. **GitHub workflows have new version**:
   ```bash
   echo "=== Workflow version check ===" && \
   grep -rn 'go-version' ecommerce-infrastructure/.github/workflows/
   ```

6. **dlv version is updated**:
   ```bash
   echo "=== dlv version check ===" && \
   grep -rn 'delve' ecommerce-infrastructure/docker/Dockerfile.*
   ```

7. **Build verification** — run tests from workspace root:
   ```bash
   go build ./...
   ```

8. **Test verification**:
   ```bash
   go test ./...
   ```

9. **Report** — present a summary table to the user:

   | Step | Status |
   |------|--------|
   | Go installed | ✅/❌ (version) |
   | go.work updated | ✅/❌ (count) |
   | go.mod updated | ✅/❌ (count) |
   | Dockerfiles updated | ✅/❌ (count) |
   | GitHub workflows updated | ✅/❌ (count) |
   | dlv updated | ✅/❌ (version) |
   | Go tools reinstalled | ✅/❌ (count) |
   | Build passes | ✅/❌ |
   | Tests pass | ✅/❌ |
