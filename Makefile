.PHONY: help terraform-fmt terraform-validate terraform-init terraform-plan terraform-apply build-layer clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

terraform-fmt: ## Format Terraform files
	terraform fmt -recursive terraform/

terraform-validate: ## Validate Terraform configuration
	cd terraform/modules/github-runner && terraform init -backend=false && terraform validate
	cd terraform/environments/prod && terraform init -backend=false && terraform validate

terraform-init: ## Initialize Terraform
	cd terraform/environments/prod && terraform init

terraform-plan: ## Run Terraform plan
	cd terraform/environments/prod && terraform plan

terraform-apply: ## Run Terraform apply
	cd terraform/environments/prod && terraform apply

build-layer: ## Build Lambda layer with dependencies
	./build-lambda-layer.sh

clean: ## Clean temporary files
	rm -f terraform/modules/github-runner/lambda/*.zip
	rm -f lambda-layer.zip
	rm -rf lambda-layer/