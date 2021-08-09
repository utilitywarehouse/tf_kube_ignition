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

variable "containerd_log_level" {
  description = "Log level for the containerd daemon (debug, info, warn, error, fatal, panic)"
  default     = "warn"
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
  default     = "v3.4.13"
}

variable "node_exporter_image_url" {
  description = "Where to get the node_exporter image from."
  default     = "quay.io/prometheus/node-exporter"
}

variable "node_exporter_image_tag" {
  description = "The version of the node_exporter image to use."
  default     = "v1.2.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version, used to specify k8s.gcr.io docker image version and Kubernetes binaries"
  default     = "v1.21.0"
}

variable "cluster_dns" {
  description = "List of DNS server IP addresses. Used by kubelet."
  type        = list(string)
}

variable "master_address" {
  description = "The address of the kubernetes API server, typically of their load balancer. Used by the worker kubelet."
}

variable "external_apiserver_address" {
  description = "The external address passed to apiservers to use when generating externalized URLs. If nothing passed the master_address will be used."
  default     = ""
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
  type        = list(string)
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
  type        = list(string)
}

variable "cfssl_additional_files" {
  description = "Additional files to include in the igntion config data for the cfssl node."
  default     = []
  type        = list(string)
}

variable "etcd_additional_systemd_units" {
  description = "Additional systemd units to include in the igntion config data for etcd nodes."
  default     = []
  type        = list(string)
}

variable "etcd_additional_files" {
  description = "Additional files to include in the igntion config data for etcd nodes."
  default     = []
  type        = list(string)
}

variable "master_additional_systemd_units" {
  description = "Additional systemd units to include in the igntion config data for master nodes."
  default     = []
  type        = list(string)
}

variable "master_additional_files" {
  description = "Additional files to include in the igntion config data for master nodes."
  default     = []
  type        = list(string)
}

variable "worker_additional_systemd_units" {
  description = "Additional systemd units to include in the igntion config data for worker nodes."
  default     = []
  type        = list(string)
}

variable "worker_additional_files" {
  description = "Additional files to include in the igntion config data for worker nodes."
  default     = []
  type        = list(string)
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

variable "cfssl_data_volumeid" {
}

variable "etcd_data_volumeids" {
  type = list(string)
}

# We are using default docker daemon bridge address here (172.17.0.1) to address
# registry mirror. Ideally we would use localhost, but there is a bug with IPVS
# and using localhost:<nodeport> ::
# https://github.com/kubernetes/kubernetes/issues/67730
variable "dockerhub_mirror_endpoint" {
  description = "DockerHub mirror endpoint"
  default     = "http://172.17.0.1:30001"
}

variable "dockerhub_username" {
  description = "Docker Hub user"
}

variable "dockerhub_password" {
  description = "Docker Hub password"
}

variable "crictl_version" {
  description = "The version of the crictl release to install"
  default     = "v1.19.0"
}

variable "crictl_verification" {
  description = "Hash to verify crictl release tar.gz"
  default     = "sha512-fbbb34a1667bcf94df911a92ab6b70a9d2b34da967244a222f288bf0135c587cbfdcc89deedc5afd1823e109921df9caaa4e9ff9cc39e55a9b8cdea8eb6ebe72"
}

variable "feature_gates" {
  description = "https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/"
  type        = map(string)

  # example default feature gates:
  # ```
  # default = {
  #   "ExpandPersistentVolumes"   = "true"
  #   "PodShareProcessNamespace"  = "true"
  # }
  # ```
  default = {}
}

variable "admission_plugins" {
  description = "https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/"
  default     = "NodeRestriction"
}

locals {
  # Comma separated list for cli flas use, example output:
  # `ExpandPersistentVolumes=true,PodShareProcessNamespace=true,AdvancedAuditing=false`
  feature_gates_csv = join(",", formatlist("%s=%s", keys(var.feature_gates), values(var.feature_gates)))

  # yaml fragment for config file use, example output:
  # ```
  #   AdvancedAuditing: false
  #   ExpandPersistentVolumes: true
  #   PodShareProcessNamespace: true
  # ```
  #
  # note the two white space chars at the start of the line, this corresponds to the
  # formatting in worker-kubelet-conf.yaml and master-kubelet-conf.yaml
  feature_gates_yaml_fragment = join("\n  ", formatlist("%s: %s", keys(var.feature_gates), values(var.feature_gates)))

  # cluster_dns list formatted for KubeletConfiguration yaml
  #
  # example:
  #  clusterDNS: ${cluster_dns}
  #  ...
  #  clusterDNS:
  #    - "169.254.20.10"
  #    - "10.3.0.10"
  #
  cluster_dns_yaml = join("", formatlist("\n  - \"%s\"", var.cluster_dns))
}
