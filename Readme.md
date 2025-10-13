# Tailscale Kubernetes POC

This POC demonstrates bidirectional connectivity between Kubernetes and Tailscale:

1. **Ingress (K8s → Tailnet)**: Nginx service in Kubernetes exposed to the Tailscale network
2. **Egress (Tailnet → K8s)**: Services running on Tailscale nodes accessible from within the Kubernetes cluster

## Prerequisites

* Tailscale account with admin access
* Maybe another tailscale account simulating an employee (also admin access)
* Docker on your local machine
* Nix and direnv which will in turn install kubeclt, k3d, helm and k9s to have a local cluster (and a machine strong enough)
* Helm 3.x installed

## Setup

* Make sure you have chosen a nice custom name for your tailnet
* Make sure you have activated ssl in your tailnet
* Configure tag ownership in your Tailscale ACL policy:
  - Go to https://login.tailscale.com/admin/acls/file
  - Add the following to your ACL policy:
```json
{
  "tagOwners": {
    "tag:k8s-operator": [],
    "tag:k8s": ["tag:k8s-operator"],
  }
}
```
* Create the oAuth clients in the Tailscale admin console:
  - Go to https://login.tailscale.com/admin/settings/oauth
  - Create OAuth client with scopes: "Devices" (Write) and "Auth" (Write)
 - Add tags  (e.g., `tag:k8s-operator`)
  - export them like:
```bash
export CLIENT_ID="your-client-id"
export CLIENT_SECRET="your-client-secret"
```

This POC is now split into three separate Helm charts with namespace isolation:

1. **tailscale-operator**: Just the Tailscale Kubernetes operator (deployed in `default` namespace)
2. **tailscale-poc-ingress**: Nginx service exposed to Tailscale network (deployed in `tailscale-ingress` namespace)
3. **tailscale-poc-egress**: Access external Tailscale services from K8s (deployed in `tailscale-egress` namespace)

## Ingress (K8s → Tailnet)

### Deploy Individual Components
```bash
# Create a k3d cluster
make create-cluster

# Deploy just the operator (requires CLIENT_ID and CLIENT_SECRET env vars)
make deploy-operator

# Deploy ingress POC (requires operator)
make deploy-ingress
```
Check that you can access the nginx service from your tailscale network. It should be reachable at https://nginx.YOUR_TAILNET.ts.net

## External Service Access (Cluster Egress)
```bash
# Deploy egress POC (requires operator)
make deploy-egress
```
### Step 1: Set up a Test Service on a Tailscale Node

On any machine in your Tailscale network (e.g., your laptop, a server), run a simple HTTP server:
```bash
# Navigate to a directory with some files
cd /tmp
echo "Hello from Tailscale node!" > index.html

# Start a simple HTTP server
python3 -m http.server 8080

# Expose the port to Tailscale
sudo tailscale serve 8080
```
### Step 2: Find Your Tailscale Node Information

1. **Get your MagicDNS name**:
   - Go to https://login.tailscale.com/admin/machines
   - Find your machine and copy its MagicDNS name (e.g., `my-laptop.my-tailnet.ts.net`)

Replace the placeholders in `examples/external-service-values.yaml`:
- `YOUR_MACHINE.YOUR_TAILNET.ts.net`: Your actual MagicDNS name

## Step 4: Deploy with External Service Configuration
```bash
# Deploy with external service configuration
make deploy-egress
```
## Step 5: Verify the Configuration

1. **Check that the external service was created**:
```bash
kubectl get services -A
```
You should see a service named `my-laptop-webserver`.

2. **Check the service details**:
```bash
kubectl describe service test-webserver
```
The `External Name` should be updated by the Tailscale operator (not "placeholder").

3. **Check Tailscale operator logs**:
```bash
kubectl logs -n tailscale -l app=tailscale-operator
```
## Step 6: Test Connectivity

### Automated Testing
```bash
# Run the automated test script
make test-external-services
# check the test-script output for manual testing
```
