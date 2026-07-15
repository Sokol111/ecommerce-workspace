---
name: release-api
description: Use when releasing an ecommerce-*-api protobuf contract for production or CI and bumping its version in consuming services. Do not use for local go.work development.
---

# Release an `-api` contract and bump consumers

Coordinate the **release-then-bump** flow across two or more independent repositories.
This is required **only for production/CI**: locally everything resolves through the root
`go.work`, so an `-api` change is visible to consumers immediately with no release.

## When to use

- A `.proto` contract changed in an `ecommerce-*-api` repo and that change must reach a deployed
  service, rather than local development only.

## Preconditions

- All `.proto` edits are done. Generated code under `gen/` is **never** hand-edited.
- Releases trigger on a push to the `VERSION` file on `master` (see the api repo's
  `.github/workflows/release.yml`), which calls the reusable `api-release.yml` in
  `ecommerce-infrastructure` for buf breaking-change checks, generated-code verification,
  TypeScript publishing, tagging, and GitHub Release creation.

## Procedure

### Step 1: Regenerate and verify in the `-api` repo

```bash
make generate
git status
```

Run these commands inside `ecommerce-<name>-api`. Confirm that only intended `gen/` and `.proto`
changes exist. CI runs a **buf breaking-change check**; if the contract change is breaking, confirm
with the user before selecting a version and adapting consumers.

### Step 2: Bump `VERSION` and release the API repo

1. Read `VERSION` and choose the next semver version according to the change.
2. Update `VERSION`.
3. Commit the API repository independently:

```bash
git add VERSION proto/ gen/
git commit -m "release: v<new> - <summary>"
git push origin master
```

4. Wait until the Go module tag and GitHub Release exist before bumping consumers. Otherwise
   `go get` cannot resolve the new version.

### Step 3: Bump every consumer's pinned version

Find consumers:

```bash
rg -l 'ecommerce-<name>-api' --glob go.mod .
```

For each consuming service repository:

```bash
go get github.com/Sokol111/ecommerce-<name>-api@v<new>
go mod tidy
make build && make test-unit
git add go.mod go.sum
git commit -m "chore: bump ecommerce-<name>-api to v<new>"
git push
```

The consuming service's own `VERSION` bump then flows through CD as usual.

## Notes

- **Per-repo commits.** The API bump and every consumer bump are separate commits in separate
  repositories. Never commit across repository boundaries.
- **TS consumers.** The Nuxt UIs consume the published TypeScript package
  `@sokol111/ecommerce-*-api`. For local UI development use `pnpm link:local`; production uses the
  published package version.
- **Local development.** For local testing, skip this skill: edit the `.proto`, run
  `make generate`, and the root Go workspace resolves the API change immediately.
