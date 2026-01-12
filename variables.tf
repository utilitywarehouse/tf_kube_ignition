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

variable "enable_coreos_metadata_sshkeys_service" {
  description = "Whether to enable the coreos-metadata-sshkeys@core.service"
  default     = false
}

variable "force_boot_reprovisioning" {
  description = "Force a new Ignition run on every reboot and wipe root filesystem"
  default     = false
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
  default     = "gcr.io/etcd-development/etcd"
}

variable "etcd_image_tag" {
  description = "The version of the etcd image to use."
  default     = "v3.6.5"
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
  default     = "v1.8.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version, used to specify registry.k8s.io docker image version and Kubernetes binaries"
  default     = "v1.35.0"
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
  default = "1.6.5"
}

variable "cfssl_binary_sha512" {
  default = "sha512-c90e56051954eb930e8f410b05c12ffdc1ac67de4625174d2996d204062367e3f73a9506c4b3ac2af274b3739e16d6d2d790a50047f2ad98b014a4fb5aac1491"
}

variable "cfssljson_binary_sha512" {
  default = "sha512-32964c8babd7d64d90878006ae75cecf89bbb84a2bb0b4602005fe2ad731a04c74ed2f662586caee7e33d18173b9980f752e099bd383db8f626c77517bb1ce3f"
}

variable "etcd_data_volumeids" {
  type = list(string)
}

variable "dockerhub_mirror_endpoint" {
  description = "DockerHub mirror endpoint"
}

variable "dockerhub_username" {
  description = "Docker Hub user"
}

variable "dockerhub_password" {
  description = "Docker Hub password"
}

variable "nginx_image" {
  description = "https://github.com/nginx/nginx/releases"
  default     = "nginx:1.29.4-alpine"
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

variable "apiserver_runtime_config" {
  description = "https://kubernetes.io/docs/tasks/administer-cluster/enable-disable-api/"
  default     = []
  type        = list(string)
}

variable "system_reserved_cpu" {
  description = "Passed to nodes kubelet config as systemReserved cpu value"
  default     = "1000m"
}

variable "system_reserved_memory" {
  description = "Passed to nodes kubelet config as systemReserved memory value"
  default     = "2Gi"
}

variable "control_plane_pod_cpu_limits" {
  description = "Set the cpu limits for the control plane static pods (kube-apiserver, kube-scheduler, etc.)"
  default     = "6"
}

variable "eviction_threshold_memory_soft" {
  description = "Amount of available memory that triggers soft eviction. In bytes to facilitate exporting it as metric"
  default     = "2147483648" # 2Gi(2^31 bytes)
}

variable "eviction_threshold_memory_hard" {
  description = "Amount of available memory that triggers hard eviction. In bytes to facilitate exporting it as metric"
  default     = "1073741824" # 1Gi(2^30 bytes)
}

locals {
  component_cloud_provider = can(regex("aws|gce", var.cloud_provider)) ? "external" : var.cloud_provider

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
  #  clusterDNS:${cluster_dns}
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
