variable "enable_container_linux_updates" {
  description = "Whether to enable automatic updates for Container Linux."
  default     = true
}

variable "etcd_image_url" {
  description = "Where to get the etcd image from."
  default     = "quay.io/coreos/etcd"
}

variable "etcd_image_tag" {
  description = "The version of the etcd image to use."
  default     = "v3.2.2"
}

variable "node_exporter_image_url" {
  description = "Where to get the node_exporter image from."
  default     = "quay.io/prometheus/node-exporter"
}

variable "node_exporter_image_tag" {
  description = "The version of the node_exporter image to use."
  default     = "v0.14.0"
}

variable "fluentd_image_url" {
  description = "Where to get the fluentd image from."
  default     = "utilitywarehouse/fluentd"
}

variable "fluentd_image_tag" {
  description = "The version of the fluentd image to use."
  default     = "2.0.3"
}

variable "hyperkube_image_url" {
  description = "Where to get the hyperkube image from."
  default     = "quay.io/coreos/hyperkube"
}

variable "hyperkube_image_tag" {
  description = "The version of the hyperkube image to use."
  default     = "v1.7.0_coreos.0"
}

variable "ssl_s3_bucket" {
  description = "The S3 bucket where SSL tars are kept for nodes."
}

variable "cluster_dns" {
  description = "Comma-separated list of DNS server IP address. Used by kubelet."
}

variable "master_address" {
  description = "The address of the kubernetes API server, typically of their load balancer. Used by kube-proxy."
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

variable "sumologic_url" {
  description = "The SumoLogic collector endpoint to ship logs to. Used by fluentd on etcd nodes."
}
