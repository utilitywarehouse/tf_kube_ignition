variable "cidr_block" {}

variable "host" {}

output "address" {
  value = "${cidrhost(var.cidr_block, var.host)}"
}
