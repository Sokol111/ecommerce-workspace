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

.PHONY: setup update status

## Clone all repositories
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
update:
	@$(foreach repo,$(REPOS),\
		if [ -d "$(repo)" ]; then \
			echo "[pull] $(repo)" && git -C $(repo) pull --rebase; \
		fi;)

## Show git status for all repositories
status:
	@$(foreach repo,$(REPOS),\
		echo "=== $(repo) ===" && git -C $(repo) status --short --branch;)

# --- Dev container (isolated Claude Code sandbox) ---
#
# Editing/k3d/Tilt stay native on the host; only Claude Code runs inside the
# container (DinD-isolated from host secrets). See .devcontainer/ and
# /home/ihsokolo/.claude/plans/container-dev-giggly-thimble.md for rationale.

WORKSPACE := $(CURDIR)
CORP_CA := $(WORKSPACE)/ecommerce-infrastructure/environments/local/certs/ca-certificates.crt
DEVCONTAINER_LABEL := devcontainer.local_folder=$(WORKSPACE)

# devcontainer CLI (Node, host-side) needs the corporate CA to fetch features/images
# through the corporate proxy. NODE_EXTRA_CA_CERTS is exported for every target below.
export NODE_EXTRA_CA_CERTS := $(CORP_CA)

.PHONY: devcontainer-up claude devcontainer-exec devcontainer-stop devcontainer-status \
	devcontainer-logs devcontainer-rebuild devcontainer-clean

## Build (if needed) and start the dev container
devcontainer-up:
	@: $${ANTHROPIC_AUTH_TOKEN:?ANTHROPIC_AUTH_TOKEN must be exported on the host}
	@: $${NODE_AUTH_TOKEN:?NODE_AUTH_TOKEN must be exported on the host}
	devcontainer up --workspace-folder $(WORKSPACE)

## Run Claude Code inside the dev container (interactive; pass ARGS="-p '...'" for one-shot)
claude: devcontainer-up
	devcontainer exec --workspace-folder $(WORKSPACE) claude $(ARGS)

## Run an arbitrary command inside the dev container, e.g. `make devcontainer-exec CMD="go build ./..."`
devcontainer-exec: devcontainer-up
	devcontainer exec --workspace-folder $(WORKSPACE) bash -lc '$(CMD)'

## Stop the dev container (data in named volumes is preserved)
devcontainer-stop:
	@docker stop $$(docker ps --filter "label=$(DEVCONTAINER_LABEL)" -q) 2>/dev/null || echo "not running"

## Show whether the dev container is running
devcontainer-status:
	@docker ps -a --filter "label=$(DEVCONTAINER_LABEL)" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'

## Tail the dev container's logs
devcontainer-logs:
	@docker logs -f $$(docker ps -a --filter "label=$(DEVCONTAINER_LABEL)" -q | head -1)

## Force a full rebuild of the dev container image (config or Dockerfile changed)
devcontainer-rebuild:
	@: $${ANTHROPIC_AUTH_TOKEN:?ANTHROPIC_AUTH_TOKEN must be exported on the host}
	@: $${NODE_AUTH_TOKEN:?NODE_AUTH_TOKEN must be exported on the host}
	devcontainer up --workspace-folder $(WORKSPACE) --remove-existing-container

## Remove the dev container AND its named volumes (chat history, DinD state) — irreversible
devcontainer-clean:
	@docker stop $$(docker ps --filter "label=$(DEVCONTAINER_LABEL)" -q) 2>/dev/null || true
	@docker rm $$(docker ps -a --filter "label=$(DEVCONTAINER_LABEL)" -q) 2>/dev/null || true
	@docker volume rm ecommerce-claude-home 2>/dev/null || true
	@docker volume ls --format '{{.Name}}' | grep '^dind-var-lib-docker-' | xargs -r docker volume rm 2>/dev/null || true
