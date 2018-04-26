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
  source = "github.com/utilitywarehouse/tf_kube_ignition"

  cloud_provider        = "aws"
  cluster_dns           = "10.3.0.10"
  dns_domain            = "kube.example.com"
  master_address        = "master.kube.example.com"
  etcd_addresses        = ["10.10.0.6", "10.10.0.7", "10.10.0.8"]
  oidc_issuer_url       = "https://accounts.google.com"
  oidc_client_id        = "000000000000-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com"
  etcd_additional_files = ["${data.ignition_file.etcd-custom-file.id}"]
  cfssl_server_address  = "10.10.0.5"
  cfssl_ca_cn           = "Example Kube CA"
}
```
