variable "node_name_command" {
  type = "map"

  default = {
    ""    = "hostname -f"
    "aws" = "curl -s http://169.254.169.254/latest/meta-data/local-hostname"
    "gce" = "curl -s http://metadata.google.internal/computeMetadata/v1/instance/hostname -H Metadata-Flavor:Google"
  }
}

variable "get_ip_command" {
  type = "map"

  default = {
    ""    = "/usr/bin/ifconfig enp2s0 | grep 'inet ' | cut -d: -f2 | awk '{print $2}'"
    "aws" = "curl -s http://169.254.169.254/latest/meta-data/local-ipv4"
    "gce" = "curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H Metadata-Flavor:Google"
  }
}

variable "kubernetes_master_default_svc" {
  type = "map"

  default = {
    ""    = "10.3.0.1"
    "aws" = "10.3.0.1"
    "gce" = "10.5.0.1"
  }
}
