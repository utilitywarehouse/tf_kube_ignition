# tf_kube_ignition

This terraform module generates ignition configuration for Container Linux to help with the bootstrapping of kubernetes nodes. It requires at least Kubernetes v1.9.

## Input Variables

The input variables are documented in their description and it's best to refer to [variables.tf](variables.tf).

## Ouputs

- `master` - the rendered ignition config for master nodes
- `worker` - the rendered ignition config for worker nodes
- `etcd` - the rendered ignition config for etcd nodes
- `cfssl` - the rendered ignition config for cfssl server

## Usage

Below is an example of how you might use this terraform module:

```hcl
module "ignition" {
  source = "github.com/utilitywarehouse/tf_kube_ignition?ref=1.0.0"

  cloud_provider                           = "aws"
  enable_container_linux_update-engine     = true
  enable_container_linux_locksmithd_master = false
  enable_container_linux_locksmithd_worker = false
  dns_domain                               = "${var.role_name}.${var.account}.${var.vpc_dns_zone_name}"
  cluster_dns                              = "10.3.0.10"
  master_instance_count                    = "3"
  master_address                           = "master.kube.example.com"
  etcd_addresses                           = ["10.10.0.6", "10.10.0.7", "10.10.0.8"]
  oidc_issuer_url                          = "https://accounts.google.com"
  oidc_client_id                           = "000000000000-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com"
  cfssl_ca_cn                              = "Example CA"
  cfssl_server_address                     = "${var.cfssl_instance_address}"
  cfssl_node_renew_timer                   = "*-*-* 00/6:00:00"
  cfssl_data_volumeid                      = "${module.cluster.cfssl_data_volumeid}"
  etcd_data_volumeids                      = "${module.cluster.etcd_data_volumeids}"
  etcd_additional_files                    = ["${data.ignition_file.if.rendered}"]
  etcd_additional_systemd_units            = ["${data.ignition_systemd_unit.isu.rendered}", "${data.ignition_systemd_unit.isu2.rendered}"]
  master_additional_systemd_units          = ["${data.ignition_systemd_unit.isu.rendered}"]
  worker_additional_systemd_units          = ["${data.ignition_systemd_unit.isu.rendered}"]
  cfssl_additional_systemd_units           = ["${data.ignition_systemd_unit.isu.rendered}"]
}
```

## Certificates

Certificates are fetched from a central CFSSL server. Workers cannot impersonate master components because:
- Workers use `worker-auth` key (only grants access to worker profiles)
- Worker profiles enforce CN patterns: `system:node:*` or `system:kubelet:*` only
- Pattern `[^:]+` allows hostnames but blocks all `system:*` privileged CNs (Kubernetes privileged components use `system:` prefix with colons, DNS hostnames cannot contain colons per RFC 952/1123)

### CFSSL Profiles

| Profile | Auth Key | CN Pattern | Hostname SANs | Used By |
|---------|----------|------------|---------------|---------|
| `worker-client` | `worker-auth` | `system:node:*`, `system:kubelet:*`, `[^:]+` | No | Worker node certs |
| `worker-client-server` | `worker-auth` | `system:node:*`, `system:kubelet:*`, `[^:]+` | Yes | Worker kubelet serving |
| `master-client-server` | `master-auth` | `system:node:*`, `system:kubelet:*`, `system:kube-scheduler`, `system:kube-controller-manager`, `[^:]+` | Mixed | Master certs |
| `apiserver-client-server` | `master-auth` | `system:node:*`, `system:kube-apiserver-kubelet-client`, `kubernetes.*`, `localhost`, `[^:]+` | Yes | API server certs |
| `etcd-client-server` | `etcd-auth` | `*.etcd.*`, `etcd.*`, `[^:]+` | No (IP only) | ETCD certs |

**Master auth key:** All master components run on the same node with shared filesystem access to `/etc/kubernetes/ssl/`. Any compromised master component can read all certificate private keys from disk, so separate auth keys per component would be ineffective.

**Kubernetes RBAC:** Authorization uses certificate CN (username) and Organization fields (groups) only. SANs are for TLS validation, not RBAC.



### Certificate Inventory

Certificates auto-renew on a timer (configurable via `cfssl_node_renew_timer`) and are fetched at systemd service startup:

#### ETCD Nodes (1 cert)
- `node.pem` - CN=`<index>.etcd.<dns_domain>`, SANs: `etcd.<dns_domain>`, node IP

#### Worker Nodes (2 certs)
- `node.pem` - CN=`system:node:<node_name>`, ORG=`system:nodes` (no SANs - client only)
- `kubelet.pem` - CN=`system:kubelet:<node_name>`, ORG=`system:kubelets`, SANs: node IP, hostname

#### Master Nodes (6 certs)
- `node.pem` - CN=`system:node:<node_name>`, ORG=`system:nodes` (no SANs - client only)
- `kubelet.pem` - CN=`system:kubelet:<node_name>`, ORG=`system:kubelets`, SANs: node IP, hostname
- `apiserver.pem` - CN=`system:node:<node_name>`, SANs: kubernetes.*, service IP, master DNS, localhost, node IP/hostname
- `apiserver-kubelet-client.pem` - CN=`system:node:<node_name>`, ORG=`system:masters` (no SANs - client only)
- `scheduler.pem` - CN=`system:kube-scheduler` (no SANs - client only)
- `controller-manager.pem` - CN=`system:kube-controller-manager` (no SANs - client only)

#### Special Certificates (HTTP basic auth to CFSSL port 8889, masters only)
- `signing-key.pem` - Service account token signing/verification
- `proxy-ca.pem` - API aggregation layer CA
- `proxy.pem` - API aggregation layer client (CN=aggregator, ORG=system:masters)
