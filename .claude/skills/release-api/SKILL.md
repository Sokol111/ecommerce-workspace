---
name: release-api
description: 'Release an ecommerce-*-api repo (proto contract) and bump its pinned version in the consuming Go services. Prod/CI flow only — local dev resolves through go.work with no release needed.'
argument-hint: 'API repo name, e.g. "catalog-service-api"'
disable-model-invocation: true
---

# Release an `-api` contract and bump consumers

Coordinates the **release-then-bump** flow across two (or more) independent repos.
This is required **only for production/CI**: locally everything resolves through the root
`go.work`, so an `-api` change is visible to consumers immediately with no release.

## When to use

- A `.proto` contract changed in an `ecommerce-*-api` repo and that change must reach a
  deployed service (i.e. not just local dev).

## Preconditions

- All `.proto` edits are done. Generated code under `gen/` is **never** hand-edited.
- `CONTEXT`: releases trigger on a push to the `VERSION` file on `master` (see the api repo's
  `.github/workflows/release.yml`), which calls the reusable `api-release.yml` in
  `ecommerce-infrastructure` (buf breaking-change check, verify `gen/` is current, publish the
  TS package, tag + GitHub Release).

## Procedure

### Step 1 — Regenerate and verify (in the `-api` repo)

```bash
cd ecommerce-<name>-api
make generate      # buf lint + Go + TypeScript + event stubs
git status         # confirm only intended gen/ + proto changes
```
CI runs a **buf breaking-change check**. If this is a breaking change, confirm with the user
whether it's intended before bumping the version (breaking changes force consumers to adapt).

### Step 2 — Bump VERSION and commit (in the `-api` repo)

1. Read current `VERSION`, choose the next semver (patch/minor/major per the change).
2. Write the new `VERSION`.
3. Commit **the api repo on its own** (per-repo commits — this is an independent git repo):
   ```bash
   git add VERSION proto/ gen/
   git commit -m "release: v<new> — <summary>"
   git push origin master        # push to VERSION on master triggers the release
   ```
4. **Wait for the release to publish** the Go module tag before bumping consumers — otherwise
   `go get` can't resolve the new version. Confirm the GitHub Release/tag exists.

### Step 3 — Bump the pinned version in each consumer

Find every service that pins this api module:
```bash
grep -rl 'ecommerce-<name>-api' --include=go.mod .
```
For each consuming service repo:
```bash
cd ecommerce-<consumer>
go get github.com/Sokol111/ecommerce-<name>-api@v<new>
go mod tidy
make build && make test-unit     # sanity check against the new contract
git add go.mod go.sum
git commit -m "chore: bump ecommerce-<name>-api to v<new>"
git push
```
The consuming service's own release (its `VERSION` bump) then flows through CD as usual.

## Notes / gotchas

- **Per-repo commits.** The api bump and each consumer bump are separate commits in separate
  repos. Never try to commit across repo boundaries.
- **TS consumers.** The Nuxt UIs consume the published TS package (`@sokol111/ecommerce-*-api`).
  For local UI dev use `pnpm link:local`; for prod they pick up the published package version.
- **Don't confuse local vs prod.** If the goal is purely local testing, skip this entire skill —
  edit the `.proto`, `make generate`, and the workspace picks it up.
