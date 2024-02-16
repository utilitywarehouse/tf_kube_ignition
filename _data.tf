variable "node_name_command" {
  type = map(string)

  default = {
    ""    = "hostname -f"
    "aws" = "/opt/bin/aws-imdsv2 local-hostname"
    "gce" = "curl -s http://metadata.google.internal/computeMetadata/v1/instance/hostname -H Metadata-Flavor:Google"
  }
}

variable "get_ip_command" {
  type = map(string)

  default = {
    ""    = "ip route get 1.2.3.4 | head  -n 1 | awk '{print $7}'"
    "aws" = "/opt/bin/aws-imdsv2 local-ipv4"
    "gce" = "curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H Metadata-Flavor:Google"
  }
}

// master address is the first in the service subnet
locals {
  kubernetes_master_svc = cidrhost(var.service_network, 1)
}
