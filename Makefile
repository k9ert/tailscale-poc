REPO:=$(shell git rev-parse --show-toplevel)

create-cluster:
	k3d cluster create --image rancher/k3s:v1.30.4-k3s1 -v "$(REPO):/charts" \
					   --k3s-arg "--disable=traefik@server:0" \
					   --k3s-arg "--disable=servicelb@server:0"

delete-cluster:
	k3d cluster delete

all: create-cluster init deploy-services deploy

dry-run:
	helm install --dry-run tail charts/tailscale

deploy:
	helm install tailscale charts/tailscale || helm upgrade tailscale charts/tailscale

helm-dep-updates:
	for dir in $$(ls ../charts); do \
		cd ../charts/$$dir && helm dependency update && cd -; \
	done
