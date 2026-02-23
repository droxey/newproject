.PHONY: help dev build deploy

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

dev: ## Run the project locally
	@echo "TODO: add dev command"

build: ## Build the project
	@echo "TODO: add build command"

deploy: ## Deploy the project
	@echo "TODO: add deploy command"
