variable "node_name_command" {
  type = map(string)

  default = {
    ""    = "hostname -f"
    "aws" = "curl -s http://169.254.169.254/latest/meta-data/local-hostname"
    "gce" = "curl -s http://metadata.google.internal/computeMetadata/v1/instance/hostname -H Metadata-Flavor:Google"
    # Add external provider command, same as no provider one. We should be able to set
    # external cloud provider in cloud nodes that come up "vanilla" and rery on cloud
    # controllers to work. In the future node_name_command should default to the non
    # cloud version commands and we should delete the cloud specific options
    "external" = "hostname -f"
  }
}

variable "get_ip_command" {
  type = map(string)

  default = {
    ""    = "ip route get 1.2.3.4 | head  -n 1 | awk '{print $7}'"
    "aws" = "curl -s http://169.254.169.254/latest/meta-data/local-ipv4"
    "gce" = "curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H Metadata-Flavor:Google"
    # Add external provider command, same as no provider one. We should be able to set
    # external cloud provider in cloud nodes that come up "vanilla" and rery on cloud
    # controllers to work. In the future node_name_command should default to the non
    # cloud version commands and we should delete the cloud specific options
    "external" = "ip route get 1.2.3.4 | head  -n 1 | awk '{print $7}'"
  }
}

// master address is the first in the service subnet
locals {
  kubernetes_master_svc = cidrhost(var.service_network, 1)
}
