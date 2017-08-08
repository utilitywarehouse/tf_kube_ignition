// generic
variable "region" {
  description = "The AWS region to deploy the cluster in."
}

variable "cluster_name" {
  description = "And identifier for the cluster."
}

variable "vpc_id" {
  description = "The ID of the VPC to create resources in."
}

variable "public_subnets" {
  description = "A list of the available public subnets in which EC2 instances can be created."
  type        = "list"
}

variable "private_subnets" {
  description = "A list of the available private subnets in which EC2 instances can be created."
  type        = "list"
}

variable "key_name" {
  description = "The name of the AWS Key Pair to be used when launching EC2 instances."
}

variable "environment" {}

variable "ssl_s3_bucket_name" {
  description = "The name of the S3 bucket that will be used to hold SSL certificates and keys for the nodes."
}

variable "containerlinux_ami_id" {
  description = "The ID of the Container Linux AMI to use for servers."
}

variable "route53_zone_id" {
  description = "The ID of the Route53 Zone to add records to."
}

variable "route53_inaddr_arpa_zone_id" {
  description = "The ID of the Route53 Zone to add pointer records to."
}

// etcd nodes
variable "etcd_instance_count" {
  default     = "3"
  description = "The number of etcd servers to launch."
}

variable "etcd_instance_type" {
  default     = "t2.small"
  description = "The type of etcd servers to launch."
}

variable "etcd_user_data" {
  description = "A list of the user data to provide to the etcd instances. Must be the same length as etcd_instance_count."
  type        = "list"
}
