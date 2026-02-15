.PHONY: init check-deps

# We kick off the initialization and configuration of the GitOps environment
init:	check-deps
	./scripts/setup_scripts/setup_argocd.sh
	./scripts/setup_scripts/setup_vault.sh
	./scripts/setup_scripts/setup_external_secrets.sh
#	./scripts/setup_scripts/setup_hello_world_app.sh
#	./scripts/setup_scripts/setup_argocd.sh

# We uninstall everything that was previously set up for this GitOps environment
uninstall:	check-deps
	./scripts/uninstall_scripts/uninstall_external_secrets.sh
	./scripts/uninstall_scripts/uninstall_vault.sh
#	./scripts/uninstall_scripts/uninstall_hello_world_app.sh
#	./scripts/uninstall_scripts/uninstall_argocd.sh

# We confirm that all the required dependencies exist -- this acts as a safety gate
check-deps:
	@command -v helm >/dev/null || { echo "helm not found"; exit 1; }
	@command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
	@kubectl get nodes >/dev/null 2>&1 || { echo "K3s cluster not reachable"; exit 1; }
	
	
#	@test -f vault-values.yaml || { echo "vault-values.yaml missing"; exit 1; }