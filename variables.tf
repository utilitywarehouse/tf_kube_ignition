variable "enable_container_linux_update-engine" {
  description = "Whether to enable automatic updates for Container Linux."
  default     = true
}

variable "enable_container_linux_locksmithd_cfssl" {
  description = "Whether to enable automatic updates for Container Linux on cfssl nodes."
  default     = true
}

variable "enable_container_linux_locksmithd_etcd" {
  description = "Whether to enable automatic updates for Container Linux on etcd nodes."
  default     = true
}

variable "enable_container_linux_locksmithd_master" {
  description = "Whether to enable automatic updates for Container Linux on kube master nodes."
  default     = true
}

variable "enable_container_linux_locksmithd_worker" {
  description = "Whether to enable automatic updates for Container Linux on kube worker nodes."
  default     = true
}

variable "dns_domain" {
  description = "The domain under which this cluster's DNS records are set (cluster-name.example.com)."
}

variable "etcd_image_url" {
  description = "Where to get the etcd image from."
  default     = "quay.io/coreos/etcd"
}

variable "etcd_image_tag" {
  description = "The version of the etcd image to use."
  default     = "v3.3.8"
}

variable "node_exporter_image_url" {
  description = "Where to get the node_exporter image from."
  default     = "quay.io/prometheus/node-exporter"
}

variable "node_exporter_image_tag" {
  description = "The version of the node_exporter image to use."
  default     = "v0.15.2"
}

variable "hyperkube_image_url" {
  description = "Where to get the hyperkube image from."
  default     = "gcr.io/google-containers/hyperkube-amd64"
}

variable "hyperkube_image_tag" {
  description = "The version of the hyperkube image to use."
  default     = "v1.11.1"
}

variable "cluster_dns" {
  description = "Comma-separated list of DNS server IP address. Used by kubelet."
}

variable "master_address" {
  description = "The address of the kubernetes API server, typically of their load balancer. Used by the worker kubelet."
}

variable "cloud_provider" {
  description = "The cloud provider. Used by the API Server, the Controller Manager and kubelet."
  default     = ""
}

variable "kube_controller_cloud_config" {
  description = "Cloud config to be passed to kube-controller manager (expected as raw text). Nothing will be passed on empty variable"
  default     = ""
}

variable "master_instance_count" {
  description = "The number of master instances in the kubernetes cluster. Used by the API server."
  default     = 3
}

variable "etcd_addresses" {
  description = "A list of IP addresses for the etcd nodes. Used by the etcd services and the API server."
  type        = "list"
}

variable "oidc_issuer_url" {
  description = "The URL of the OIDC provider. Used by the API Server."
}

variable "oidc_client_id" {
  description = "The client id for the OIDC provider. Used by the API Server."
}

variable "service_network" {
  description = "The subnet to use for kubernetes service addressing. Used by the API server."
  default     = "10.3.0.0/16"
}

variable "pod_network" {
  description = "The subnet to use for kubernetes pod addressing. Used by the Controller Manager"
  default     = "10.2.0.0/16"
}

variable "cfssl_additional_systemd_units" {
  description = "Additional systemd units to include in the igntion config data for the cfssl node."
  default     = []
  type        = "list"
}

variable "cfssl_additional_files" {
  description = "Additional files to include in the igntion config data for the cfssl node."
  default     = []
  type        = "list"
}

variable "etcd_additional_systemd_units" {
  description = "Additional systemd units to include in the igntion config data for etcd nodes."
  default     = []
  type        = "list"
}

variable "etcd_additional_files" {
  description = "Additional files to include in the igntion config data for etcd nodes."
  default     = []
  type        = "list"
}

variable "master_additional_systemd_units" {
  description = "Additional systemd units to include in the igntion config data for master nodes."
  default     = []
  type        = "list"
}

variable "master_additional_files" {
  description = "Additional files to include in the igntion config data for master nodes."
  default     = []
  type        = "list"
}

variable "worker_additional_systemd_units" {
  description = "Additional systemd units to include in the igntion config data for worker nodes."
  default     = []
  type        = "list"
}

variable "worker_additional_files" {
  description = "Additional files to include in the igntion config data for worker nodes."
  default     = []
  type        = "list"
}

variable "cfssl_ca_cn" {
  description = "The Common Name for the CA certificate."
}

variable "cfssl_ca_expiry_hours" {
  description = "The expiry time in hours for the CA certificate (defaults to 2 years)."
  default     = "17520"
}

variable "cfssl_node_expiry_hours" {
  description = "The expiry time in hours for the nodes certificats (defaults to a week)."
  default     = "168"
}

variable "cfssl_node_renew_timer" {
  description = "The systemd timestamp that triggers node certificate renewal (default to every day at 05:45)."
  default     = "*-*-* 05:45:00"
}

variable "cfssl_server_address" {
  description = "The IP address of the cfssl server."
}

variable "cfssl_data_volumeid" {}

variable "etcd_data_volumeids" {
  type = "list"
}

variable "feature_gates" {
  description = "https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/"
  type        = "map"

  default = {
    "ExpandPersistentVolumes"  = "true"
    "PodShareProcessNamespace" = "true"
  }
}

locals {
  # Comma separated list for cli flas use, example output:
  # `ExpandPersistentVolumes=true,PodShareProcessNamespace=true,AdvancedAuditing=false`
  feature_gates_csv = "${join(",", formatlist("%s=%s", keys(var.feature_gates), values(var.feature_gates)))}"

  # yaml fragment for config file use, example output:
  # ```
  #   AdvancedAuditing: false
  #   ExpandPersistentVolumes: true
  #   PodShareProcessNamespace: true
  # ```
  #
  # note the two white space chars at the start of the line, this corresponds to the
  # formatting in worker-kubelet-conf.yaml and master-kubelet-conf.yaml
  feature_gates_yaml_fragment = "${join("\n  ", formatlist("%s: %s", keys(var.feature_gates), values(var.feature_gates)))}"
}
