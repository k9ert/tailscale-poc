# Tailscale Kubernetes POC Makefile

# Create k3d cluster with Kubernetes 1.31.13 (latest stable)
create-cluster:
	k3d cluster create tailscale-poc --image rancher/k3s:v1.31.13-k3s1 --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"

# Delete k3d cluster
delete-cluster:
	k3d cluster delete tailscale-poc

# Deploy Tailscale operator only
deploy-operator:
	# check for env vars
	[ -n "$$CLIENT_ID" ] || (echo "CLIENT_ID is not set"; exit 1)
	[ -n "$$CLIENT_SECRET" ] || (echo "CLIENT_SECRET is not set"; exit 1)
	helm install --set-string=tailscale-operator.oauth.clientId=$$CLIENT_ID,tailscale-operator.oauth.clientSecret=$$CLIENT_SECRET tailscale-operator charts/tailscale-operator || helm upgrade --set-string=tailscale-operator.oauth.clientId=$$CLIENT_ID,tailscale-operator.oauth.clientSecret=$$CLIENT_SECRET tailscale-operator charts/tailscale-operator

# Deploy ingress POC (requires operator to be deployed first)
deploy-ingress:
	helm install tailscale-poc-ingress charts/tailscale-poc-ingress --create-namespace || helm upgrade tailscale-poc-ingress charts/tailscale-poc-ingress

# Deploy egress POC (requires operator to be deployed first)
deploy-egress:
	helm install tailscale-poc-egress charts/tailscale-poc-egress -f examples/external-service-values.yaml --create-namespace || helm upgrade tailscale-poc-egress charts/tailscale-poc-egress -f examples/external-service-values.yaml

test-external-services:
	# Test external service connectivity
	./scripts/test-external-service.sh

# Clean up everything
clean:
	helm uninstall tailscale-poc-egress --ignore-not-found
	helm uninstall tailscale-poc-ingress --ignore-not-found
	helm uninstall tailscale-operator --ignore-not-found
	kubectl delete namespace tailscale-egress --ignore-not-found
	kubectl delete namespace tailscale-ingress --ignore-not-found
