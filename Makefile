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
