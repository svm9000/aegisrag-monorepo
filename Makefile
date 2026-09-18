# ==============================================================================
# UNIVERSAL AUTOMATION HARNESS (CROSS-PLATFORM DEPLOYMENT ENGINE)
# ==============================================================================

.PHONY: verify-all infra build deploy test clean

# Detect underlying operating system environment structures
ifeq ($(OS),Windows_NT)
    # Windows Execution Layer Mapping Rules
    RUN_SCRIPT = powershell -ExecutionPolicy Bypass -File ./orchestrate.ps1
    verify-all:
		$(RUN_SCRIPT) -Action verify-all
    infra:
		$(RUN_SCRIPT) -Action infra
    build:
		$(RUN_SCRIPT) -Action build
    deploy:
		$(RUN_SCRIPT) -Action deploy
    test:
		$(RUN_SCRIPT) -Action test
    clean:
		$(RUN_SCRIPT) -Action clean
else
    # Linux & macOS Native Shell Execution Mapping Rules
    verify-all:
		@echo "Bootstrapping Linux/macOS Context Environment..."
		minikube start --driver=docker
		docker-compose up -d
		@until [ $$(docker inspect --format='{{.State.Health.Status}}' aegisrag-kms) = "healthy" ]; do sleep 2; done
		cd terraform && terraform init && terraform apply -auto-approve
		eval $$(minikube docker-env) && cd packages/backend && docker build -t aegisrag-backend:local .
		kubectl apply -f k8s/deployment.yaml
		kubectl rollout status deployment/aegisrag-backend --timeout=90s
    infra:
		docker-compose up -d
		cd terraform && terraform init && terraform apply -auto-approve
    build:
		eval $$(minikube docker-env) && cd packages/backend && docker build -t aegisrag-backend:local .
    deploy:
		kubectl apply -f k8s/deployment.yaml
    test:
		cd packages/backend && uv run pytest -v tests/
    clean:
		kubectl delete -f k8s/deployment.yaml --ignore-not-found=true || true
		cd terraform && terraform destroy -auto-approve || true
		docker-compose down -v
		minikube delete
endif
