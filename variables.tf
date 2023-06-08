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

variable "omit_locksmithd_service" {
  description = "Whether to omit locksmithd service from ignition. It should be used when passing locksmithd service as additional config to avoid ignition failures"
  default     = false
}

variable "set_etcd_locksmithd_dropin_reboot_config" {
  description = "Whether to create a dropin to configure etcd locksmithd reboot windows"
  default     = true
}

variable "omit_update_engine_service" {
  description = "Whether to omit update-engine service from ignition. It should be used when passing update-engine service as additional config to avoid ignition failures"
  default     = false
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
  default     = "v3.5.7"
}

variable "etcd_data_dir" {
  description = "Directory where etcd data is stored"
  default     = "/var/lib/etcd"
}

variable "node_exporter_image_url" {
  description = "Where to get the node_exporter image from."
  default     = "quay.io/prometheus/node-exporter"
}

variable "node_exporter_image_tag" {
  description = "The version of the node_exporter image to use."
  default     = "v1.6.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version, used to specify registry.k8s.io docker image version and Kubernetes binaries"
  default     = "v1.26.3"
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

variable "master_additional_labels" {
  description = "Map of additional labels to append to role=master in the respective master nodes kubelet flag."
  type        = map(string)
  default     = {}
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

variable "worker_additional_labels" {
  description = "Map of additional labels to append to role=worker in the respective worker nodes kubelet flag."
  type        = map(string)
  default     = {}
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

variable "cfssl_version" {
  default = "1.6.4"
}

variable "cfssl_binary_sha512" {
  default = "sha512-816e96a4377d4430af7fafdc3a93dfe274877950e79ffeb4ad744fdb4d17fb7606d7fa6d5efd490efae64baa7d2e2857e82d6899b4f4a6a0cdbed9ddab4dc146"
}

variable "cfssljson_binary_sha512" {
  default = "sha512-4e787c1da296c3fe2b89dade7e2de6441aa1f60bfc7243953b978fd0166d40737a68f485443bc2f809187e80389f658c06f5fae356b76f30934099096d683268"
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

variable "nginx_image" {
  description = "https://github.com/nginx/nginx/releases"
  default     = "nginx:1.24-alpine"
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

variable "system_reserved_cpu" {
  description = "Passed to nodes kubelet config as systemReserved cpu value"
  default     = "1000m"
}

variable "system_reserved_memory" {
  description = "Passed to nodes kubelet config as systemReserved memory value"
  default     = "2Gi"
}

variable "eviction_threshold_memory_soft" {
  description = "Amount of available memory that triggers soft eviction. In bytes to facilitate exporting it as metric"
  default     = "2147483648" # 2Gi(2^31 bytes)
}

variable "eviction_threshold_memory_hard" {
  description = "Amount of available memory that triggers hard eviction. In bytes to facilitate exporting it as metric"
  default     = "1073741824" # 1Gi(2^30 bytes)
}

variable "containerd_no_shim" {
  description = "Do not user containerd shim, only used for live restore which we don't use"
  default     = false
  type        = bool
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

  # Kubelet labels
  master_kubelet_labels = join(",", concat(["role=master"], formatlist("%s=%s", keys(var.master_additional_labels), values(var.master_additional_labels))))
  worker_kubelet_labels = join(",", concat(["role=worker"], formatlist("%s=%s", keys(var.worker_additional_labels), values(var.worker_additional_labels))))
}
