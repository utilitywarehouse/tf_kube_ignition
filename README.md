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
  etcd_additional_files                    = ["${data.ignition_file.if.id}"]
  etcd_additional_systemd_units            = ["${data.ignition_systemd_unit.isu.id}", "${data.ignition_systemd_unit.isu2.id}"]
  master_additional_systemd_units          = ["${data.ignition_systemd_unit.isu.id}"]
  worker_additional_systemd_units          = ["${data.ignition_systemd_unit.isu.id}"]
  cfssl_additional_systemd_units           = ["${data.ignition_systemd_unit.isu.id}"]
}
```

## Certificates

Certificates for the cluster components are fetched from the `cfssl` server, and they all use the same `CA`.

As part of `kubelet` systemd service pre start processes we fetch all the needed certificates, following `kubeadm` [docs](https://kubernetes.io/docs/reference/setup-tools/kubeadm/implementation-details/#generate-the-necessary-certificates). All kube components authenticate against apiserves using a client certificate and in particular `CN` as RBAC user and `ORG` as RBAC group.

We get the following certificates on every `kubelet` service restart:

### Master

#### Kubelet

- A `node` certificate to be used by kubelet kubeconfig to authenticate against apiserver
```
CN=system:node:<node_name>
ORG=system:master-nodes
```

- A `kubelet` certificate to serve apiserver requests on port `:10250`, based on [doc](https://kubernetes.io/docs/concepts/architecture/master-node-communication/#apiserver-to-kubelet)
```
CN=system:kubelet:<node_name>
ORG=system:kubelets
```

#### Apiserver

- A serving certificate for the API server (`apiserver`)
Common Name and Organisation are not important here as the cert will not be used to authenticate against apiservers, but the certificate need to specify all the alternative DNS names that the apiservers listen to.

- A client certificate for the API server to connect to the kubelets securely (`apiserver-kubelet-client`)
```
CN=system:node:<node_name>
ORG=system:masters
```

#### Kube Scheduler

- A `scheduler` certificate to be used in kube-scheduler's kubeconfig file to communicate with apiservers.
```
CN=system:kube-scheduler
ORG=
```

#### Kube Controller Manager

- A `controller-manager` certificate to be used in kube-controller-manager's kubeconfig file to communicate with apiservers.
```
CN=system:kube-controller-manager
ORG=
```

### Node

#### Kubelet

- A `node` certificate to be used by kubelet kubeconfig to authenticate against apiserver
```
CN=system:node:<node_name>
ORG=system:nodes
```

- A `kubelet` certificate to serve apiserver requests on port `:10250`, based on [doc](https://kubernetes.io/docs/concepts/architecture/master-node-communication/#apiserver-to-kubelet)
```
CN=system:kubelet:<node_name>
ORG=system:kubelets
```
