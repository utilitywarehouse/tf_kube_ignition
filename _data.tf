variable "node_name_command" {
  type = "map"

  default = {
    ""    = "hostname -f"
    "aws" = "curl -s http://169.254.169.254/latest/meta-data/local-hostname"
  }
}
