.DEFAULT_GOAL := help

GIT_BASE ?= git@github.com:Sokol111

REPOS := \
	ecommerce-admin-ui \
	ecommerce-catalog-service \
	ecommerce-catalog-service-api \
	ecommerce-category-query-service \
	ecommerce-category-query-service-api \
	ecommerce-commons \
	ecommerce-image-service \
	ecommerce-image-service-api \
	ecommerce-infrastructure \
	ecommerce-platform-ui \
	ecommerce-product-query-service \
	ecommerce-product-query-service-api \
	ecommerce-tenant-service \
	ecommerce-tenant-service-api \
	ecommerce-ui

## Clone all repositories
.PHONY: setup
setup:
	@$(foreach repo,$(REPOS),\
		if [ -d "$(repo)" ]; then \
			echo "[skip] $(repo)"; \
		else \
			echo "[clone] $(repo)" && git clone $(GIT_BASE)/$(repo).git; \
		fi;)
	@echo ""
	@echo "Done. Open workspace:"
	@echo "  code ecommerce.code-workspace"

## Pull latest changes in all repositories
.PHONY: update
update:
	@$(foreach repo,$(REPOS),\
		if [ -d "$(repo)" ]; then \
			echo "[pull] $(repo)" && git -C $(repo) pull --rebase; \
		fi;)

## Show git status for all repositories
.PHONY: status
status:
	@$(foreach repo,$(REPOS),\
		echo "=== $(repo) ===" && git -C $(repo) status --short --branch;)

## Synchronize workspace dependencies into module go.mod files
.PHONY: work-sync
work-sync:
	go work sync

## Show this help message
.PHONY: help
help:
	@echo "Available targets:"
	@awk 'BEGIN { comment = "" } \
		/^## / { comment = substr($$0, 4); next } \
		/^[a-zA-Z0-9_-]+:/ { \
			if (comment != "") { \
				gsub(/:.*$$/, "", $$1); \
				printf "  \033[36m%-24s\033[0m %s\n", $$1, comment; \
				comment = ""; \
			} \
		}' $(MAKEFILE_LIST)

# --- Dev container (isolated OpenCode sandbox) ---
#
# Editing/k3d/Tilt stay native on the host; only OpenCode runs inside the
# container (DinD-isolated from host secrets). See .devcontainer/ and AGENTS.md.

WORKSPACE := $(CURDIR)
CORP_CA := $(WORKSPACE)/ecommerce-infrastructure/environments/local/certs/ca-certificates.crt
DEVCONTAINER_LABEL := devcontainer.local_folder=$(WORKSPACE)

# devcontainer CLI (Node, host-side) needs the corporate CA to fetch features/images
# through the corporate proxy. NODE_EXTRA_CA_CERTS is exported for every target below.
export NODE_EXTRA_CA_CERTS := $(CORP_CA)


## Build (if needed) and start the dev container
.PHONY: devcontainer-up
devcontainer-up:
	@: $${NODE_AUTH_TOKEN:?NODE_AUTH_TOKEN must be exported on the host}
	devcontainer up --workspace-folder $(WORKSPACE)

## Run OpenCode inside the dev container (autonomous; pass ARGS="run '...'" for one-shot)
.PHONY: opencode
opencode: devcontainer-up
	devcontainer exec --workspace-folder $(WORKSPACE) opencode --auto $(ARGS)

## Authenticate OpenCode with GitHub Copilot inside the isolated container volume
.PHONY: opencode-auth-github
opencode-auth-github: devcontainer-up
	devcontainer exec --workspace-folder $(WORKSPACE) opencode auth login --provider github

## Run an arbitrary command inside the dev container, e.g. `make devcontainer-exec CMD="go build ./..."`
.PHONY: devcontainer-exec
devcontainer-exec: devcontainer-up
	devcontainer exec --workspace-folder $(WORKSPACE) bash -lc '$(CMD)'

## Stop the dev container (data in named volumes is preserved)
.PHONY: devcontainer-stop
devcontainer-stop:
	@docker stop $$(docker ps --filter "label=$(DEVCONTAINER_LABEL)" -q) 2>/dev/null || echo "not running"

## Show whether the dev container is running
.PHONY: devcontainer-status
devcontainer-status:
	@docker ps -a --filter "label=$(DEVCONTAINER_LABEL)" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'

## Tail the dev container's logs
.PHONY: devcontainer-logs
devcontainer-logs:
	@docker logs -f $$(docker ps -a --filter "label=$(DEVCONTAINER_LABEL)" -q | head -1)

## Force a full rebuild of the dev container image (config or Dockerfile changed)
.PHONY: devcontainer-rebuild
devcontainer-rebuild:
	@: $${NODE_AUTH_TOKEN:?NODE_AUTH_TOKEN must be exported on the host}
	devcontainer up --workspace-folder $(WORKSPACE) --remove-existing-container

## Remove the dev container AND its named volumes (OpenCode state, DinD state) - irreversible
.PHONY: devcontainer-clean
devcontainer-clean:
	@docker stop $$(docker ps --filter "label=$(DEVCONTAINER_LABEL)" -q) 2>/dev/null || true
	@docker rm $$(docker ps -a --filter "label=$(DEVCONTAINER_LABEL)" -q) 2>/dev/null || true
	@docker volume rm ecommerce-opencode-data 2>/dev/null || true
	@docker volume ls --format '{{.Name}}' | grep '^dind-var-lib-docker-' | xargs -r docker volume rm 2>/dev/null || true
