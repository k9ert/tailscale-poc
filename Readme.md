
# Tailscale operator POC

based on: https://www.youtube.com/watch?v=XbTUWZt5ljQ

## prerequisites

* tailscale account
* k8s cluster (e.g. k3d)
* helm
* Rename your tailnet: https://login.tailscale.com/admin/dns
* Activate MagicDNS: https://login.tailscale.com/admin/dns
* Activate https in your tailscale account (make sure you have done the other two steps first): https://login.tailscale.com/admin/dns
* Create those tags in your tailscale settings: https://login.tailscale.com/admin/acls/file
```
"tagOwners": {
   "tag:k8s-operator": [],
   "tag:k8s": ["tag:k8s-operator"],
}
```
* Create the oAuth clients with "Device Core" write and Auth Write and the k8s-operator tag and copy them in the values.yaml

## deploying the cluster, the nginx and the tailscale operator

```bash
make create-cluster
make deploy
```

Got to your tailscale machine page, copy the dns-name of the nginx machine and copy it into your browser.

## Scratchpad

```
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update
cd tailscale
help dependencies update
helm install tailscale .
```



# Resources

* https://tailscale.com/kb/1236/kubernetes-operator
* 
